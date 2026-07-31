//
//  FTSessionReplayFeature.m
//  SessionReplay
//
//  Created by hulilei on 2024/7/4.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTSessionReplayFeature.h"
#import "FTSegmentRequest.h"
#import "FTPerformancePresetOverride.h"
#import "FTSessionReplayCoreImports.h"
#import "FTRecorder.h"
#import "FTSessionReplayTouches.h"
#import "FTWindowObserver.h"
#import "FTRecordingCoordinator.h"
#import "FTSessionReplayConfig+Private.h"
#import "FTTLV.h"
#import "FTResourceProcessor.h"
#import "FTResourcesWriter.h"
#import "FTSnapshotProcessor.h"
#import "FTRecordWriter.h"
#import "FTSRRecord.h"
#import "FTFileWriter.h"
#import "FTFeatureStorage.h"
#import "FTFeatureScope.h"
#import "FTLimitedSizeSet.h"
#import "FTWKWebViewHandler+SessionReplay.h"
#import "FTScreenChangeScheduler.h"

@interface FTSessionReplayFeature()<FTMessageReceiver,FTSRWebTrackingProtocol>
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong) dispatch_queue_t processorsQueue;
@property (nonatomic, strong) FTSessionReplayConfig *config;
@property (nonatomic, strong) FTFeatureScope *recordScope;
@property (nonatomic, strong) FTFeatureScope *resourceScope;
@property (nonatomic, copy) NSString *lastViewID;
@property (nonatomic, strong) FTLimitedSizeSet *needCheckSlots;
@property (nonatomic, strong) FTRecordingCoordinator *recordingCoordinator;

@end
@implementation FTSessionReplayFeature
-(instancetype)initWithConfig:(FTSessionReplayConfig *)config{
    self = [super init];
    if(self){
        _name = @"session-replay";
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        _processorsQueue = dispatch_queue_create("com.ft.session-replay.processors", attr);
        _requestBuilder = [[FTSegmentRequest alloc]init];
        FTPerformancePresetOverride *performancePresetOverride = [[FTPerformancePresetOverride alloc]initWithMeanFileAge:2 minUploadDelay:0.6];
        performancePresetOverride.maxFileSize = FT_MAX_DATA_LENGTH;
        performancePresetOverride.maxObjectSize = FT_MAX_DATA_LENGTH;
        performancePresetOverride.initialUploadDelay = 1;
        performancePresetOverride.uploadDelayChangeRate = 0.75;
        _performanceOverride = performancePresetOverride;
        _windowObserver = [[FTWindowObserver alloc]init];
        FTSessionReplayTouches *touches = [[FTSessionReplayTouches alloc]initWithWindowObserver:_windowObserver];
        _config = [config copy];
        _needCheckSlots = [[FTLimitedSizeSet alloc]initWithMaxCount:10];
        #if TARGET_OS_OSX
        NSTimeInterval captureInterval = FTSessionReplayMacOSCaptureInterval;
        #else
        NSTimeInterval captureInterval = 0.1;
        #endif
        FTScreenChangeScheduler *scheduler = [[FTScreenChangeScheduler alloc]
            initWithMinimumInterval:captureInterval];
        __weak typeof(self) weakSelf = self;
        _recordingCoordinator = [[FTRecordingCoordinator alloc]initWithConfig:_config
                                                               processorsQueue:_processorsQueue
                                                                     scheduler:scheduler
                                                                       touches:touches
                                                      trackingConsentDidChange:^(FTTrackingConsent trackingConsent) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf.recordScope updateTrackingConsent];
            [strongSelf.resourceScope updateTrackingConsent];
        }];
        [[FTModuleManager sharedInstance] addMessageReceiver:self];
        [[FTModuleManager sharedInstance] registerService:NSProtocolFromString(@"FTSRWebTrackingProtocol") instance:self];
    }
    return self;
}
- (void)configureHeatmapIdentifierRegistry {
    id<FTHeatmapIdentifierRegistry> registry = [[FTModuleManager sharedInstance] getRegisterService:@protocol(FTHeatmapIdentifierRegistry)];
    [registry setEnableHeatmap:self.config.enableHeatmap];
    [registry setHeatmapIdentifiers:@{}];
}
-(void)startWithRecordStorage:(FTFeatureStorage *)recordStorage resourceStorage:(FTFeatureStorage *)resourceStorage resourceDataStore:(nullable id<FTDataStore>)dataStore{
    [self configureHeatmapIdentifierRegistry];
    __weak typeof(self) weakSelf = self;
    FTTrackingConsentProvider trackingConsentProvider = ^FTTrackingConsent{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return FTTrackingConsentNotGranted;
        }
        return strongSelf.recordingCoordinator.trackingConsent;
    };
    FTFeatureScope *recordScope = [[FTFeatureScope alloc]initWithStorage:recordStorage trackingConsentProvider:trackingConsentProvider];
    self.recordScope = recordScope;
    FTFeatureScope *resourceScope = [[FTFeatureScope alloc]initWithStorage:resourceStorage trackingConsentProvider:trackingConsentProvider];
    self.resourceScope = resourceScope;

    FTResourcesWriter *resource = [[FTResourcesWriter alloc]initWithFeatureScope:resourceScope dataStore:dataStore];
    FTResourceProcessor *resourceProcessor = [[FTResourceProcessor alloc]initWithQueue:self.processorsQueue resourceWriter:resource];
    FTRecordWriter *recordWriter = [[FTRecordWriter alloc]initWithFeatureScope:recordScope];
    FTSnapshotProcessor *srProcessor = [[FTSnapshotProcessor alloc]initWithQueue:self.processorsQueue recordWriter:recordWriter resourceProcessor:resourceProcessor];

    FTRecorder *windowRecorder = [[FTRecorder alloc]initWithWindowObserver:self.windowObserver snapshotProcessor:srProcessor additionalNodeRecorders:self.config.additionalNodeRecorders enableSwiftUI:self.config.enableSwiftUI enableHeatmap:self.config.enableHeatmap];
    self.recordingCoordinator.recorder = windowRecorder;
    [self.recordScope updateTrackingConsent];
    [self.resourceScope updateTrackingConsent];
}
- (void)startRecording{
    [self.recordingCoordinator startRecording];
}
#pragma mark =========== FTMessageReceiver ============
- (void)receive:(NSString *)key message:(NSDictionary *)message {
    if([key isEqualToString:FTMessageKeyRUMContext]){
        [self handleRUMContextMessage:message];
    }else if ([key isEqualToString:FTMessageKeyWebViewSR]){
        [self handleWebViewSRMessage:message];
    }else if([key isEqualToString:FTMessageKeySRSampleRateUpdate]){
        [self handleSRSampleRateUpdateMessage];
    }
}
#pragma mark - deal receive message
- (void)handleRUMContextMessage:(NSDictionary *)message{
    [self.recordingCoordinator handleRUMContextMessage:message];
}
- (void)handleWebViewSRMessage:(NSDictionary *)message{
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
            NSDictionary *bindInfo = message[FT_LINK_RUM_KEYS];
            if (event && slotID && viewID) {
                NSDictionary *currentRumContext = strongSelf.recordingCoordinator.currentRUMContext;
                if (!currentRumContext) {
                    return;
                }
                [strongSelf.recordScope webViewEventWriteContext:^(FTFeatureContext *context, id<FTWriter> writer) {
                    if (context.trackingConsent == FTTrackingConsentNotGranted) {
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
                    record.bindInfo = bindInfo;
                    NSData *data = [record toJSONData];
                    [writer write:data forceNewFile:force];
                    strongSelf.lastViewID = viewID;
                }];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}
- (void)handleSRSampleRateUpdateMessage{
    [self.recordingCoordinator handleSampleRateUpdate];
}
#pragma mark -- deal web sr local file
- (void)checkLocalFiles:(NSMutableDictionary *)rootNodeDict slotID:(NSString *)slotID{
    @try {
        NSNumber *type = [rootNodeDict valueForKey:@"type"];
        if ([type isEqualToNumber:@4]) {
            NSDictionary *data = [rootNodeDict valueForKey:@"data"];
            NSString *href = [data valueForKey:@"href"];
            if ([href containsString:@"file://"]) {
                [self.needCheckSlots addObject:slotID];
            }
        } else if ([_needCheckSlots containsObject:slotID] && ([type isEqualToNumber:@2] || [type isEqualToNumber:@3])) {
            NSMutableDictionary *data = [self mutableDictionaryFromObject:[rootNodeDict valueForKey:@"data"]];
            if (!data) {
                return;
            }
            rootNodeDict[@"data"] = data;
            if ([type isEqualToNumber:@2]) {
                NSMutableDictionary *node = [self mutableDictionaryFromObject:data[@"node"]];
                if (!node) {
                    return;
                }
                data[@"node"] = node;
                [self addCssTextToHrefWithFileScheme:node slotID:slotID];
            }else{
                NSMutableArray *childNodes = [self mutableArrayFromObject:data[@"adds"]];
                if (childNodes.count>0) {
                    data[@"adds"] = childNodes;
                    for (NSUInteger i = 0; i < childNodes.count; i++) {
                        NSMutableDictionary *childNode = [self mutableDictionaryFromObject:childNodes[i]];
                        if (childNode) {
                            childNodes[i] = childNode;
                            NSMutableDictionary *node = [self mutableDictionaryFromObject:childNode[@"node"]];
                            if (!node) {
                                continue;
                            }
                            childNode[@"node"] = node;
                            [self addCssTextToHrefWithFileScheme:node slotID:slotID];
                        }
                    }
                }
            }
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
    NSMutableArray *childNodes = [self mutableArrayFromObject:rootNodeDict[@"childNodes"]];
    if (childNodes) {
        rootNodeDict[@"childNodes"] = childNodes;
        for (NSUInteger i = 0; i < childNodes.count; i++) {
            NSMutableDictionary *childNode = [self mutableDictionaryFromObject:childNodes[i]];
            if (!childNode) {
                continue;
            }
            childNodes[i] = childNode;
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
    
    // Step 2: Get the attributes dictionary of the current node.
    NSMutableDictionary *attributes = [self mutableDictionaryFromObject:nodeDict[@"attributes"]];
    if (!attributes) return; // No attributes dictionary, return directly
    nodeDict[@"attributes"] = attributes;
    
    // Step 3: Check if href exists in attributes and its value contains file://
    id hrefObject = attributes[@"href"];
    if (![hrefObject isKindOfClass:NSString.class]) {
        return;
    }
    NSString *hrefValue = hrefObject;
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
- (NSMutableDictionary *)mutableDictionaryFromObject:(id)object {
    if (![object isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    if ([object isKindOfClass:NSMutableDictionary.class]) {
        return object;
    }
    return [object mutableCopy];
}
- (NSMutableArray *)mutableArrayFromObject:(id)object {
    if (![object isKindOfClass:NSArray.class]) {
        return nil;
    }
    if ([object isKindOfClass:NSMutableArray.class]) {
        return object;
    }
    return [object mutableCopy];
}
#pragma mark =========== FTSRWebTrackingProtocol ============
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
-(void)dealloc{
    [[FTModuleManager sharedInstance] removeMessageReceiver:self];
    FTInnerLogDebug(@"[session-replay] SessionReplayFeature dealloc");
}
@end

#endif
