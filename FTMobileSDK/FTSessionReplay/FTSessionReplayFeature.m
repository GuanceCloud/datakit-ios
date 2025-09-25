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
#import "FTFeatureStorage.h"
@interface FTSessionReplayFeature()<FTMessageReceiver,FTSRWebTrackingProtocol>
@property (nonatomic, strong) NSTimer *timer;
@property (atomic, strong) NSDictionary *currentRUMContext;
@property (nonatomic, strong) FTRecorder *windowRecorder;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, strong) FTSessionReplayTouches *touches;
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong) dispatch_queue_t processorsQueue;
@property (nonatomic, strong) FTSessionReplayConfig *config;
@property (nonatomic, assign) BOOL shouldStart;
@property (nonatomic, assign) BOOL sampledForErrorReplay;
@property (nonatomic, strong) FTFeatureStorage *recordStorage;
@property (nonatomic, strong) id<FTWriter> webViewWriter;
@property (atomic, copy) NSString *lastViewID;
@property (nonatomic, strong) NSMutableSet *needCheckSlots;
@end
@implementation FTSessionReplayFeature
-(instancetype)initWithConfig:(FTSessionReplayConfig *)config{
    self = [super init];
    if(self){
        _name = @"session-replay";
        _processorsQueue = dispatch_queue_create("com.ft.session-replay.processors", 0);
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
        _shouldStart = NO;
        _needCheckSlots = [NSMutableSet new];
        self.sampledForErrorReplay = NO;
        [[FTModuleManager sharedInstance] addMessageReceiver:self];
        [[FTModuleManager sharedInstance] registerService:NSProtocolFromString(@"FTSRWebTrackingProtocol") instance:self];
    }
    return self;
}
-(void)startWithRecordStorage:(FTFeatureStorage *)recordStorage{
    _recordStorage = recordStorage;
    FTSnapshotProcessor *srProcessor = [[FTSnapshotProcessor alloc]initWithQueue:self.processorsQueue writer:recordStorage.writer];
    FTRecorder *windowRecorder = [[FTRecorder alloc]initWithWindowObserver:self.windowObserver snapshotProcessor:srProcessor resourceProcessor:nil additionalNodeRecorders:self.config.additionalNodeRecorders];
    self.windowRecorder = windowRecorder;
}
//-(void)startWithWriter:(id<FTWriter>)writer
//           cacheWriter:(id<FTCacheWriter>)cacheWriter
//         webViewWriter:(id<FTWriter>)webViewWriter
//        resourceWriter:(id<FTWriter>)resourceWriter
//     resourceDataStore:(id<FTDataStore>)dataStore{
//    // image resource writer
////    FTResourceWriter *resource = [[FTResourceWriter alloc]initWithWriter:resourceWriter dataStore:dataStore];
////    FTResourceProcessor *resourceProcessor = [[FTResourceProcessor alloc]initWithQueue:self.processorsQueue resourceWriter:resource];
//    _cacheWriter = cacheWriter;
//    _writer = writer;
//    _webViewWriter = webViewWriter;
//    FTSnapshotProcessor *srProcessor = [[FTSnapshotProcessor alloc]initWithQueue:self.processorsQueue writer:writer];
//    FTRecorder *windowRecorder = [[FTRecorder alloc]initWithWindowObserver:self.windowObserver snapshotProcessor:srProcessor resourceProcessor:nil additionalNodeRecorders:self.config.additionalNodeRecorders];
//    self.windowRecorder = windowRecorder;
//}

- (void)setSampledForErrorReplay:(BOOL)sampledForErrorReplay{
    _sampledForErrorReplay = sampledForErrorReplay;
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        [self.windowRecorder.snapshotProcessor changeWriter:sampledForErrorReplay? self.recordStorage.cacheWriter:self.recordStorage.writer needUpdateFullSnapshot:sampledForErrorReplay];
        if(sampledForErrorReplay){
            [self.recordStorage.cacheWriter active];
            self.webViewWriter = self.recordStorage.webViewCacheWriter;
        }else{
            [self.recordStorage.cacheWriter inactive];
            self.webViewWriter = self.recordStorage.webViewWriter;
        }
    }];
}
-(void)start{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
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
    if([key isEqualToString:FTMessageKeyRUMContext]){
        if ([self.currentRUMContext isEqualToDictionary:message]) {
            return;
        }
        [self onRUMContextChanged:message];
    }else if ([key isEqualToString:FTMessageKeyWebViewSR]){
        __weak typeof(self) weakSelf = self;
        id <FTWriter> webViewWriter = self.webViewWriter;
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
                if (event && slotID && viewID) {
                    NSDictionary *currentRumContext = strongSelf.currentRUMContext;
                    if (!currentRumContext) {
                        return;
                    }
                    NSMutableDictionary *newEvent = [event mutableCopy];
                    [newEvent setValue:slotID forKey:@"slotId"];
                    [strongSelf checkLocalFiles:newEvent slotID:slotID];
                    BOOL force = strongSelf.lastViewID == nil || ![strongSelf.lastViewID isEqualToString:viewID];
                    FTSRWebRecord *record = [[FTSRWebRecord alloc]init];
                    record.viewID = viewID;
                    record.sessionID = currentRumContext[FT_RUM_KEY_SESSION_ID];
                    record.applicationID = currentRumContext[FT_APP_ID];
                    record.records = @[newEvent];
                    NSData *data = [record toJSONData];
                    [webViewWriter write:data forceNewFile:force];
                    strongSelf.lastViewID = viewID;
                }
            } @catch (NSException *exception) {
                FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
            }
        });
    }
}
- (void)onRUMContextChanged:(NSDictionary *)context{
    NSDictionary *rumContext = [self.currentRUMContext copy];
    if(rumContext == nil || ![context[FT_RUM_KEY_SESSION_ID] isEqualToString:rumContext[FT_RUM_KEY_SESSION_ID]]){
        BOOL isErrorSession = [context[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue];
        BOOL isSampled = [FTBaseInfoHandler randomSampling:self.sampleRate];
        BOOL srOnErrorSampleRate = isSampled? NO: [FTBaseInfoHandler randomSampling:self.config.sessionReplayOnErrorSampleRate];
        
        self.shouldStart = isSampled || srOnErrorSampleRate;
        // Whether to use temporary cache (when it's an error session, or not sampled by regular sampling but error sampling is enabled)
        BOOL sampledForErrorReplay = isErrorSession || srOnErrorSampleRate;
        if (self.sampledForErrorReplay != sampledForErrorReplay) {
            self.sampledForErrorReplay = sampledForErrorReplay;
        }
    }
    self.currentRUMContext = context;
    [self evaluateRecordingConditions];
}
- (void)evaluateRecordingConditions{
    if (self.shouldStart) {
        [self start];
    } else {
        [self stop];
    }
    [self updateHasReplay];
}
- (void)updateHasReplay{
    // FT_SESSION_HAS_REPLAY, whether there is session replay data collection, cache type also counts
    // FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY, cache type data
    [[FTModuleManager sharedInstance] postMessage:FTMessageKeySessionHasReplay message:@{
        FT_SESSION_HAS_REPLAY:@(self.shouldStart),
        FT_RUM_SESSION_REPLAY_SAMPLE_RATE:@(self.sampleRate),
        FT_RUM_SESSION_REPLAY_ON_ERROR_SAMPLE_RATE:@(self.config.sessionReplayOnErrorSampleRate),
        FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY:@(self.sampledForErrorReplay)
    }];
}
- (void)captureNextRecord{
    @try {
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
    } @catch (NSException *exception) {
        FTInnerLogError(@"[session-replay] EXCEPTION: %@", exception.description);
    }
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
- (void)checkLocalFiles:(NSMutableDictionary *)rootNodeDict slotID:(NSString *)slotID{
    @try {
        NSNumber *type = [rootNodeDict valueForKey:@"type"];
        if ([type isEqualToNumber:@4]) {
            NSDictionary *data = [rootNodeDict valueForKey:@"data"];
            NSString *href = [data valueForKey:@"href"];
            if ([href containsString:@"file://"]) {
                [self.needCheckSlots addObject:slotID];
            }
        } else if ([_needCheckSlots containsObject:slotID] && [type isEqualToNumber:@2]) {
            NSMutableDictionary *data = [rootNodeDict valueForKey:@"data"];
            NSMutableDictionary *node = data[@"node"];
            [self addCssTextToHrefWithFileScheme:node slotID:slotID];
            [self.needCheckSlots removeObject:slotID];

        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"[session-replay] checkLocalFiles fail: %@", exception.description);
    }
}
- (void)addCssTextToHrefWithFileScheme:(NSMutableDictionary *)rootNodeDict slotID:(NSString *)slotID {
    if (!rootNodeDict) return;
    
    // 1. Process the current node first (check if it meets the condition that href contains file://)
    [self processSingleNode:rootNodeDict];
    
    // 2. Recursively process the child nodes of the current node (handle nested structures)
    NSMutableArray *childNodes = rootNodeDict[@"childNodes"];
    if ([childNodes isKindOfClass:[NSMutableArray class]]) {
        for (NSMutableDictionary *childNode in childNodes) {
            [self addCssTextToHrefWithFileScheme:childNode slotID:slotID];
        }
    }
}
/// Process a single node (check href and add _cssText)
- (void)processSingleNode:(NSMutableDictionary *)nodeDict {
    if (!nodeDict) return;
    
    // Step 1: First check if the tagName is link; if not, return directly (no subsequent logic processing)
    NSString *nodeTagName = nodeDict[@"tagName"];
    if (!nodeTagName || ![nodeTagName isEqualToString:@"link"]) {
        return; // Not a link node, no need to process href
    }
    
    // Step 2: Get the attributes dictionary of the current node (ensure it's a mutable dictionary first to avoid modification failure)
    NSMutableDictionary *attributes = nodeDict[@"attributes"];
    // If attributes is an immutable dictionary, first convert it to a mutable dictionary (otherwise modification will fail)
    if ([attributes isKindOfClass:[NSDictionary class]] && ![attributes isKindOfClass:[NSMutableDictionary class]]) {
        attributes = [attributes mutableCopy];
        nodeDict[@"attributes"] = attributes; // Reassign back to the node dictionary
    }
    if (!attributes) return; // No attributes dictionary, return directly
    
    // Step 3: Check if href exists in attributes and its value contains file://
    NSString *hrefValue = attributes[@"href"];
    if (hrefValue && [hrefValue containsString:@"file://"] && !attributes[@"_cssText"]) {
        // Step 4: Add _cssText:fileDataStr
        NSString *cssPath = [hrefValue stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:cssPath]) {
            NSData *fileData = [NSData dataWithContentsOfFile:cssPath];
            NSString *cssString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
            if (cssString) {
                attributes[@"_cssText"] = cssString;
            }
        }
    }
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
