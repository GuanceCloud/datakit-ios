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
#import "FTSRRecord.h"
#import "FTFileWriter.h"
#import "FTSRWebTrackingProtocol.h"
@interface FTSessionReplayFeature()<FTMessageReceiver,FTSRWebTrackingProtocol>
@property (nonatomic, strong) NSTimer *timer;
@property (atomic, assign) BOOL isSampled;
@property (atomic, strong) NSDictionary *currentRUMContext;
@property (nonatomic, strong) FTRecorder *windowRecorder;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, strong) FTSessionReplayTouches *touches;
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong) dispatch_queue_t processorsQueue;
@property (nonatomic, strong) FTSessionReplayConfig *config;
@property (nonatomic, strong) id<FTWriter> webViewWriter;
@property (atomic, copy) NSString *lastViewID;
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
        [[FTModuleManager sharedInstance] registerService:NSProtocolFromString(@"FTSRWebTrackingProtocol") instance:self];
    }
    return self;
}

-(void)startWithWriter:(id<FTWriter>)writer webViewWriter:(id<FTWriter>)webViewWriter resourceWriter:(nullable id<FTWriter>)resourceWriter resourceDataStore:(nullable id<FTDataStore>)dataStore{
    // image resource writer
//    FTResourceWriter *resource = [[FTResourceWriter alloc]initWithWriter:resourceWriter dataStore:dataStore];
//    FTResourceProcessor *resourceProcessor = [[FTResourceProcessor alloc]initWithQueue:self.processorsQueue resourceWriter:resource];
    self.webViewWriter = webViewWriter;
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
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf captureNextRecord];
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
    if([key isEqualToString:FTMessageKeyRUMContext]){
        NSDictionary *rumContext = self.currentRUMContext;
        if(rumContext == nil || ![message[FT_RUM_KEY_SESSION_ID] isEqualToString:rumContext[FT_RUM_KEY_SESSION_ID]]){
            BOOL isSampled = [FTBaseInfoHandler randomSampling:self.sampleRate];
            if(isSampled){
                [self start];
            }else{
                [self stop];
            }
            [[FTModuleManager sharedInstance] postMessage:FTMessageKeySessionHasReplay message:@{FT_SESSION_HAS_REPLAY:@(isSampled)}];
            FTInnerLogDebug(@"[session-replay] session(id:%@) has replay:%@",message[FT_RUM_KEY_SESSION_ID],(isSampled?@"true":@"false"));
            self.isSampled = isSampled;
            self.currentRUMContext = message;
        }else if (![self.currentRUMContext[FT_KEY_VIEW_ID] isEqualToString:message[FT_KEY_VIEW_ID]]){
            self.currentRUMContext = message;
        }
    }else if ([key isEqualToString:FTMessageKeyWebViewSR]){
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.processorsQueue, ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            @try {
                NSString *slotID = message[@"slotId"];
                NSDictionary *view = message[@"view"];
                NSString *viewID = view[@"id"];
                NSDictionary *event = message[@"data"];
                NSDictionary *container = message[@"container"];
                if (event && slotID && viewID) {
                    NSDictionary *currentRumContext = strongSelf.currentRUMContext;
                    if (!currentRumContext) {
                        return;
                    }
                    NSMutableDictionary *newEvent = [event mutableCopy];
                    [newEvent setValue:slotID forKey:@"slotId"];
                    BOOL force = strongSelf.lastViewID == nil || ![strongSelf.lastViewID isEqualToString:viewID];
                    FTSRWebRecord *record = [[FTSRWebRecord alloc]init];
                    record.viewID = viewID;
                    record.container = container;
                    record.sessionID = currentRumContext[FT_RUM_KEY_SESSION_ID];
                    record.applicationID = currentRumContext[FT_APP_ID];
                    record.records = @[newEvent];
                    NSData *data = [record toJSONData];
                    [strongSelf.webViewWriter write:data forceNewFile:force];
                    strongSelf.lastViewID = viewID;
                }
            } @catch (NSException *exception) {
                FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
            }
        });
    }
}
- (void)captureNextRecord{
    NSDictionary *rumContext = self.currentRUMContext;
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
-(NSString *)getSessionReplayPrivacyLevel{
    if (self.config.touchPrivacy == FTTouchPrivacyLevelShow) {
        if (self.config.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskSensitiveInputs) {
            return @"allow";
        }else if (self.config.textAndInputPrivacy == FTTextAndInputPrivacyLevelMaskAllInputs){
            return @"mask-user-input";
        }
    }
    return @"mask";
}
-(NSArray *)getAllowedWebViewHosts{
    return @[];
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
