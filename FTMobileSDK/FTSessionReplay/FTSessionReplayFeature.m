//
//  FTSessionReplayFeature.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayFeature.h"
#import "FTSegmentRequest.h"
#import "FTPerformancePresetOverride.h"
#import "FTThreadDispatchManager.h"
#import "FTRecorder.h"
#import "FTConstants.h"
#import "FTViewAttributes.h"
#import "FTBaseInfoHandler.h"
#import "FTSessionReplayTouches.h"
#import "FTWindowObserver.h"
#import "FTSessionReplayConfig+Private.h"
#import "FTTLV.h"
#import "FTResourceProcessor.h"
#import "FTResourceWriter.h"
#import "FTSnapshotProcessor.h"
#import "FTModuleManager.h"
#import "FTMessageReceiver.h"
#import "FTLog+Private.h"
#import "FTFileWriter.h"
@interface FTSessionReplayFeature()<FTMessageReceiver>
@property (nonatomic, strong) NSTimer *timer;
@property (atomic, strong) NSDictionary *currentRUMContext;
@property (nonatomic, strong) FTRecorder *windowRecorder;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, strong) FTSessionReplayTouches *touches;
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong) dispatch_queue_t processorsQueue;
@property (nonatomic, strong) FTSessionReplayConfig *config;
@property (nonatomic, strong) id<FTCacheWriter> cacheWriter;
@property (nonatomic, strong) id<FTWriter> writer;
@end
@implementation FTSessionReplayFeature
-(instancetype)initWithConfig:(FTSessionReplayConfig *)config{
    self = [super init];
    if(self){
        _name = @"session-replay";
        _processorsQueue = dispatch_queue_create("com.guance.session-replay.processors", 0);
        _sampleRate = config.sampleRate;
        _requestBuilder = [[FTSegmentRequest alloc]init];
        FTPerformancePresetOverride *performancePresetOverride = [[FTPerformancePresetOverride alloc]initWithMeanFileAge:2 minUploadDelay:0.6];
        performancePresetOverride.maxFileSize = FT_MAX_DATA_LENGTH;
        performancePresetOverride.maxObjectSize = FT_MAX_DATA_LENGTH;
        performancePresetOverride.initialUploadDelay = 1;
        performancePresetOverride.uploadDelayChangeRate = 0.75;
        _performanceOverride = performancePresetOverride;
        _windowObserver = [[FTWindowObserver alloc]init];
        _touches = [[FTSessionReplayTouches alloc]initWithWindowObserver:_windowObserver];
        _config = [config copy];
        [[FTModuleManager sharedInstance] addMessageReceiver:self];
    }
    return self;
}

-(void)startWithWriter:(id<FTWriter>)writer cacheWriter:(id<FTCacheWriter>)cacheWriter resourceWriter:(id<FTWriter>)resourceWriter resourceDataStore:(id<FTDataStore>)dataStore{
    // image resource writer
//    FTResourceWriter *resource = [[FTResourceWriter alloc]initWithWriter:resourceWriter dataStore:dataStore];
//    FTResourceProcessor *resourceProcessor = [[FTResourceProcessor alloc]initWithQueue:self.processorsQueue resourceWriter:resource];
    _cacheWriter = cacheWriter;
    _writer = writer;
    FTSnapshotProcessor *srProcessor = [[FTSnapshotProcessor alloc]initWithQueue:self.processorsQueue writer:writer];
    FTRecorder *windowRecorder = [[FTRecorder alloc]initWithWindowObserver:self.windowObserver snapshotProcessor:srProcessor resourceProcessor:nil additionalNodeRecorders:self.config.additionalNodeRecorders];
    self.windowRecorder = windowRecorder;
}
-(void)start{
    [self startWithTmpCache:NO];
}
-(void)startWithTmpCache:(BOOL)cache{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        [self.windowRecorder.snapshotProcessor changeWriter:cache? self.cacheWriter:self.writer needUpdateFullSnapshot:cache];
        cache?[self.cacheWriter active]:[self.cacheWriter inactive];
        if(self.timer){
            return;
        }
        __weak typeof(self) weakSelf = self;
        NSTimer *newTimer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf captureNextRecord];
        }];
        self.timer = newTimer;
        [[NSRunLoop mainRunLoop] addTimer:newTimer forMode:NSRunLoopCommonModes];
    }];
}
- (void)stop{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        if(self.timer){
            [self.timer invalidate];
            self.timer = nil;
        }
    }];
}
- (void)receive:(NSString *)key message:(NSDictionary *)message {
    if(![key isEqualToString:FTMessageKeyRUMContext]){
        return;
    }
    NSDictionary *rumContext = [self.currentRUMContext copy];
    if(rumContext == nil || ![message[FT_RUM_KEY_SESSION_ID] isEqualToString:rumContext[FT_RUM_KEY_SESSION_ID]]){
        BOOL isErrorSession = [message[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue];
        BOOL isSampled = [FTBaseInfoHandler randomSampling:self.sampleRate];
        BOOL srOnErrorSampleRate = isSampled? NO: [FTBaseInfoHandler randomSampling:self.config.sessionReplayOnErrorSampleRate];
        
        BOOL shouldStart = isSampled || srOnErrorSampleRate;
        // 是否需要使用临时缓存（当为错误会话，或未被常规采样但开启了错误采样时）
        BOOL useTmpCache = isErrorSession || srOnErrorSampleRate;
        if (shouldStart) {
            [self startWithTmpCache:useTmpCache];
        } else {
            [self stop];
        }
        // FT_SESSION_HAS_REPLAY,有没有 session replay 数据采集，cache 类型也算
        // FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY,cache 类型数据
        [[FTModuleManager sharedInstance] postMessage:FTMessageKeySessionHasReplay message:@{
            FT_SESSION_HAS_REPLAY:@(shouldStart),
            FT_RUM_SESSION_REPLAY_SAMPLE_RATE:@(self.sampleRate),
            FT_RUM_SESSION_REPLAY_ON_ERROR_SAMPLE_RATE:@(self.config.sessionReplayOnErrorSampleRate),
            FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY:@(useTmpCache)
        }];
    }
    self.currentRUMContext = message;
}
- (void)captureNextRecord{
    NSDictionary *rumContext = [self.currentRUMContext copy];
    NSString *viewID = rumContext[FT_KEY_VIEW_ID];
    if (!viewID) {
        return;
    }
    FTSRContext *context = [[FTSRContext alloc]init];
    context.sessionID = rumContext[FT_RUM_KEY_SESSION_ID];
    context.viewID = viewID;
    context.applicationID = rumContext[FT_APP_ID];
    context.date = [NSDate date];
    context.imagePrivacy = self.config.imagePrivacy;
    context.touchPrivacy = self.config.touchPrivacy;
    context.textAndInputPrivacy = self.config.textAndInputPrivacy;
    [self.windowRecorder taskSnapShot:context touchSnapshot:[self.touches takeTouchSnapshotWithContext:context]];
}
-(void)dealloc{
    if(self.timer){
        [self.timer invalidate];
        self.timer = nil;
    }
    [[FTModuleManager sharedInstance] removeMessageReceiver:self];
    FTInnerLogDebug(@"[session-replay] SessionReplayFeature dealloc");
}
@end
