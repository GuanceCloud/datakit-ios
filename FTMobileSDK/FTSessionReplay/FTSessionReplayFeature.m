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

@interface FTSessionReplayFeature()<FTMessageReceiver>
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDictionary *currentRUMContext;
@property (nonatomic, assign) BOOL isSampled;
@property (nonatomic, strong) FTRecorder *windowRecorder;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, strong) FTSessionReplayTouches *touches;
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong) dispatch_queue_t processorsQueue;
@property (nonatomic, strong) FTSessionReplayConfig *config;
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
        _config = config;
        [[FTModuleManager sharedInstance] addMessageReceiver:self];
    }
    return self;
}

-(void)startWithWriter:(id<FTWriter>)writer resourceWriter:(id<FTWriter>)resourceWriter resourceDataStore:(id<FTDataStore>)dataStore{
    // image resource writer
//    FTResourceWriter *resource = [[FTResourceWriter alloc]initWithWriter:resourceWriter dataStore:dataStore];
//    FTResourceProcessor *resourceProcessor = [[FTResourceProcessor alloc]initWithQueue:self.processorsQueue resourceWriter:resource];
    FTSnapshotProcessor *srProcessor = [[FTSnapshotProcessor alloc]initWithQueue:self.processorsQueue writer:writer];
    FTRecorder *windowRecorder = [[FTRecorder alloc]initWithWindowObserver:self.windowObserver snapshotProcessor:srProcessor resourceProcessor:nil additionalNodeRecorders:self.config.additionalNodeRecorders];
    self.windowRecorder = windowRecorder;
}
-(void)start{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        if(self.timer){
            return;
        }
        __weak typeof(self) weakSelf = self;
        self.timer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [weakSelf captureNextRecord];
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
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
    if(self.currentRUMContext == nil || ![message[FT_RUM_KEY_SESSION_ID] isEqualToString:self.currentRUMContext[FT_RUM_KEY_SESSION_ID]]){
        self.isSampled = [FTBaseInfoHandler randomSampling:self.sampleRate];
        if(self.isSampled){
            [self start];
        }else{
            [self stop];
        }
        [[FTModuleManager sharedInstance] postMessage:FTMessageKeySessionHasReplay message:@{FT_SESSION_HAS_REPLAY:@(self.isSampled)}];
        FTInnerLogDebug(@"[session-replay] session(id:%@) has replay:%@",message[FT_RUM_KEY_SESSION_ID],(self.isSampled?@"true":@"false"));
    }
    self.currentRUMContext = message;
}
- (void)captureNextRecord{
    NSString *viewID = self.currentRUMContext[FT_KEY_VIEW_ID];
    if (!viewID) {
        return;
    }
    FTSRContext *context = [[FTSRContext alloc]init];
    context.sessionID = self.currentRUMContext[FT_RUM_KEY_SESSION_ID];
    context.viewID = self.currentRUMContext[FT_KEY_VIEW_ID];
    context.applicationID = self.currentRUMContext[FT_APP_ID];
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
