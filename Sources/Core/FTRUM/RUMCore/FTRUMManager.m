//
//  FTRUMManger.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/21.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTRUMManager.h"
#import "FTIssueFieldEnricher.h"
#import "FTBaseInfoHandler.h"
#import "FTRUMSessionHandler.h"
#import "FTMonitorUtils.h"
#import "FTInnerLog.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTSDKCompat.h"
#import "FTConstants.h"
#import "FTErrorMonitorInfo.h"
#import "FTModuleManager.h"
#import "NSError+FTDescription.h"
#import "FTPresetProperty.h"
#import "FTNetworkConnectivity.h"
#import "NSDate+FTUtil.h"
#import <limits.h>
#import <math.h>
#import "FTRUMContext.h"
#import "FTMessageReceiver.h"
#import "FTRUMViewHandler.h"
#import "FTAppLifeCycle.h"
#import "FTVisitorIDManager+Private.h"
#if FT_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif
#if FT_HOST_MAC
#import <AppKit/AppKit.h>
#endif

NSString *FTStringFromAppState(FTAppState state) {
    switch (state) {
        case FTAppStateUnknown:
            return @"unknown";
        case FTAppStateStartUp:
            return @"startup";
        case FTAppStateRun:
            return @"run";
        case FTAppStateBackground:
            return @"background";
        default:
            return @"unknown";
    }
}

static NSString *FTRUMIntervalState(FTAppState state) {
    switch (state) {
        case FTAppStateRun: return FTStringFromRUMAppState(FTRUMAppStateForegroundOnly);
        case FTAppStateBackground: return FTStringFromRUMAppState(FTRUMAppStateBackgroundOnly);
        default: return FTStringFromRUMAppState(FTRUMAppStateUnknown);
    }
}
void *FTRUMQueueIdentityKey = &FTRUMQueueIdentityKey;

@interface FTRUMManager()<FTRUMSessionProtocol,FTMessageReceiver,FTRUMAppStateHistoryDelegate>
@property (nonatomic, strong) FTRUMDependencies *rumDependencies;
@property (nonatomic, assign) BOOL initialBackground;
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
// Accessed only on rumQueue; loading data is consumed by the next matching ViewStart.
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *preViewDuration;
@property (nonatomic, strong) dispatch_queue_t rumQueue;
@property (atomic,copy,readwrite) NSString *viewReferrer;
@property (atomic,copy,nullable) NSString *viewReferrerId;
- (nullable NSString *)currentVisitorIDSnapshot;
@end
@implementation FTRUMManager
-(instancetype)initWithRumDependencies:(FTRUMDependencies *)dependencies{
    self = [super init];
    if(self){
        _rumDependencies = dependencies;
        self.appState = [self initialAppState];
        dependencies.appStateHistory = [[FTRUMAppStateHistory alloc] initWithState:FTRUMIntervalState(self.appState)
                                                                          timeNs:[NSDate ft_currentNanosecondTimeStamp] background:self.initialBackground];
        _preViewDuration = [NSMutableDictionary new];
        _rumQueue = dispatch_queue_create("com.ft.rum", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_rumQueue, FTRUMQueueIdentityKey, &FTRUMQueueIdentityKey, NULL);
        [[FTModuleManager sharedInstance] addMessageReceiver:self];
        [[FTModuleManager sharedInstance] registerRUMContextSource:self];
        self.assistant = self;
        dependencies.appStateHistory.delegate = self;
        [dependencies.appStateHistory startMonitoring];
        [self notifyRumInit];
    }
    return self;
}
-(void)receive:(NSString *)key message:(NSDictionary *)message{
    NSDictionary *messageCopy = [message copy];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.rumQueue, ^{
        @try {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if([key isEqualToString:FTMessageKeySessionHasReplay]){
                NSMutableDictionary *mutableMessage = [messageCopy mutableCopy];
                BOOL hasReplay = [mutableMessage[FT_SESSION_HAS_REPLAY] boolValue];
                BOOL sampledForErrorReplay = [mutableMessage[FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY] boolValue];
                BOOL isErrorSampledSession = strongSelf.sessionHandler.context.sessionState.sampled_for_error_session;
                // If it's a normal session but session replay is error replay, hasReplay is NO
                if (!isErrorSampledSession && sampledForErrorReplay) {
                    strongSelf.rumDependencies.sessionHasReplay = @(NO);
                    [mutableMessage setValue:@(NO) forKey:FT_SESSION_HAS_REPLAY];
                }else{
                    strongSelf.rumDependencies.sessionHasReplay = @(hasReplay);
                }
                strongSelf.rumDependencies.sessionReplaySampledFields = [mutableMessage copy];
                strongSelf.rumDependencies.sampledForErrorReplay = sampledForErrorReplay;
                FTInnerLogDebug(@"[RUM] session(id:%@)  has replay:%@ sampledForErrorReplay:%@",strongSelf.sessionHandler.context.sessionState.session_id,(hasReplay?@"true":@"false"),(sampledForErrorReplay?@"true":@"false"));
            }else if([key isEqualToString:FTMessageKeyRecordsCountByViewID]){
                strongSelf.rumDependencies.sessionReplayStats = messageCopy;
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
-(void)setAppState:(FTAppState)appState{
    _appState = appState;
    self.rumDependencies.fatalErrorContext.appState = FTStringFromAppState(appState);
}
-(FTAppState)initialAppState{
#if FT_HAS_UIKIT
    if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
        UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
        if (!application) {
            return FTAppStateUnknown;
        }
        UIApplicationState initialState = application.applicationState;
        self.initialBackground = initialState == UIApplicationStateBackground;
        switch (initialState) {
            case UIApplicationStateActive:
                return FTAppStateRun;
            case UIApplicationStateBackground:
            case UIApplicationStateInactive:
            default:
                return FTAppStateStartUp;
        }
    }
    return FTAppStateUnknown;
#elif FT_HOST_MAC
    return [NSApplication sharedApplication].active ? FTAppStateRun : FTAppStateUnknown;
#else
    return FTAppStateUnknown;
#endif
}
#pragma mark ========== RUM App State ==========
- (void)appStateHistory:(FTRUMAppStateHistory *)history didChangeState:(FTRUMAppState)state time:(NSDate *)time {
    switch (state) {
        case FTRUMAppStateForegroundOnly: self.appState = FTAppStateRun; break;
        case FTRUMAppStateBackgroundOnly: self.appState = FTAppStateBackground; break;
        default: self.appState = FTAppStateUnknown; break;
    }
    if (state != FTRUMAppStateBackgroundOnly) return;
    BOOL timeComparable = history.isTimeComparable;
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMAppStateChangeModel *model = [[FTRUMAppStateChangeModel alloc] initWithAppState:state time:time timeComparable:timeComparable];
            [self process:model context:[self rumDynamicProperty]];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@", exception);
        }
    });
}
-(void)updateSampleRate:(float)sampleRate sessionOnErrorSampleRate:(float)sessionOnErrorSampleRate{
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            self.rumDependencies.sampleRate = sampleRate;
            self.rumDependencies.sessionOnErrorSampleRate = sessionOnErrorSampleRate;
            FTRUMDataModel *model = [[FTRUMDataModel alloc]init];
            model.type = FTRUMSampleRateUpdate;
            model.visitorIDSnapshot = visitorID;
            [self process:model context:@{}];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
#pragma mark - Session -
-(void)notifyRumInit{
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMDataModel *model = [[FTRUMDataModel alloc]init];
            model.type = FTRUMViewPlaceholder;
            model.visitorIDSnapshot = visitorID;
            [self process:model context:@{}];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
#pragma mark - View -
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime{
    NSString *name = [viewName copy];
    dispatch_async(self.rumQueue, ^{
        @try {
            [self.preViewDuration setValue:loadTime ? @{@"duration": loadTime} : nil forKey:name];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}

- (void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime loadStartEpochNs:(nullable NSNumber *)loadStartEpochNs {
    if (viewName.length == 0 || loadTime == nil) {
        return;
    }
    NSMutableDictionary *info = [@{@"duration": loadTime} mutableCopy];
    if ([loadStartEpochNs isKindOfClass:NSNumber.class] && isfinite(loadStartEpochNs.doubleValue) &&
        [loadStartEpochNs compare:@0] == NSOrderedDescending &&
        [loadStartEpochNs compare:@(LLONG_MAX)] != NSOrderedDescending) {
        info[@"load_start_epoch_ns"] = @(loadStartEpochNs.longLongValue);
    }
    NSString *name = [viewName copy];
    NSDictionary *loadingInfo = [info copy];
    dispatch_async(self.rumQueue, ^{
        @try {
            self.preViewDuration[name] = loadingInfo;
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
-(void)startViewWithName:(NSString *)viewName{
    [self startViewWithName:viewName property:nil];
}
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property{
    [self startViewWithName:viewName property:property trackingType:FTRUMViewTrackingTypeManual];
}
- (void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property trackingType:(FTRUMViewTrackingType)trackingType {
    [self startViewWithViewID:[FTBaseInfoHandler randomUUID] viewName:viewName property:property trackingType:trackingType];
}
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property{
    [self startViewWithViewID:viewId viewName:viewName property:property trackingType:FTRUMViewTrackingTypeAutomatic];
}
- (void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property trackingType:(FTRUMViewTrackingType)trackingType {
    if (trackingType != FTRUMViewTrackingTypeManual && trackingType != FTRUMViewTrackingTypeAutomatic) {
        FTInnerLogError(@"[RUM] Failed to start view due to invalid tracking type.");
        return;
    }
    if (!(viewId&&viewId.length>0&&viewName&&viewName.length>0)) {
        FTInnerLogError(@"[RUM] Failed to start view due to missing required fields. Please ensure 'viewName' are provided.");
        return;
    }
    // Capture event data before queueing so a busy rumQueue cannot shift the boundary.
    NSDate *time = [NSDate date];
    NSString *visitorID = [self currentVisitorIDSnapshot];
    NSString *name = [viewName copy];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *info = self.preViewDuration[name];
            NSNumber *duration = info[@"duration"] ?: @0;
            NSNumber *loadingStartEpochNs = info[@"load_start_epoch_ns"];
            [self.preViewDuration removeObjectForKey:name];
            NSDictionary *context = [self rumDynamicProperty];
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewId viewName:name viewReferrer:self.viewReferrer];
            viewModel.time = time;
            viewModel.loading_time = duration?:@0;
            viewModel.loading_start_epoch_ns = duration.longLongValue > 0 && loadingStartEpochNs.longLongValue < [time ft_nanosecondTimeStamp] ? loadingStartEpochNs : nil;
            viewModel.trackingType = trackingType;
            viewModel.type = FTRUMDataViewStart;
            viewModel.fields = property;
            viewModel.visitorIDSnapshot = visitorID;
            [self process:viewModel context:context];
            self.viewReferrer = name;
            self.viewReferrerId = viewId;
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
-(void)updateViewLoadingTime:(NSNumber *)duration{
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMViewLoadingModel *viewModel = [[FTRUMViewLoadingModel alloc]initWithDuration:duration];
            viewModel.visitorIDSnapshot = visitorID;
            [self process:viewModel context:@{}];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}

-(void)stopView{
    [self stopViewWithViewID:nil property:nil];
}
-(void)stopViewWithProperty:(NSDictionary *)property{
    [self stopViewWithViewID:nil property:property];
}
-(void)stopViewWithViewID:(NSString *)viewId property:(nullable NSDictionary *)property{
    NSDate *time = [NSDate date];
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            NSString *stopViewId = viewId?viewId:[self.sessionHandler getCurrentViewID];
            if(!stopViewId){
                return;
            }
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:stopViewId viewName:@"" viewReferrer:@""];
            viewModel.time = time;
            viewModel.type = FTRUMDataViewStop;
            viewModel.fields = property;
            viewModel.visitorIDSnapshot = visitorID;
            [self process:viewModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
#pragma mark - Action -
- (void)startAction:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    [self startAction:actionName actionType:actionType property:property heatmapAttributes:nil];
}
- (void)startAction:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property heatmapAttributes:(FTHeatmapAttributes *)heatmapAttributes{
    NSDate *time = [NSDate date];
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:actionType];
            actionModel.time = time;
            actionModel.type = FTRUMDataStartAction;
            actionModel.fields = property;
            actionModel.heatmapAttributes = heatmapAttributes;
            actionModel.visitorIDSnapshot = visitorID;
            [self process:actionModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
- (void)addAction:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    NSDate *time = [NSDate date];
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:actionType];
            actionModel.time = time;
            actionModel.type = FTRUMDataAddAction;
            actionModel.fields = property;
            actionModel.visitorIDSnapshot = visitorID;
            [self process:actionModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
- (void)addLaunch:(NSString *)name type:(NSString *)type launchTime:(NSDate *)time duration:(NSNumber *)duration property:(nullable NSDictionary *)property{
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithDuration:duration];
            launchModel.time = time;
            launchModel.action_name = name;
            launchModel.action_type = type;
            launchModel.fields = property;
            launchModel.visitorIDSnapshot = visitorID;
            [self process:launchModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}

#pragma mark - Resource -
-(void)startResourceWithKey:(NSString *)key{
    [self startResourceWithKey:key property:nil];
}
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property{
    [self startResourceWithKey:key property:property time:[NSDate date]];
}
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property time:(NSDate *)time {
    if (!key) {
        FTInnerLogError(@"[RUM] Failed to start resource due to missing required fields. Please ensure 'key' are provided.");
        return;
    }
    FTVisitorIDManager *visitorIDManager = [FTVisitorIDManager sharedInstance];
    NSString *visitorID = [visitorIDManager consumeResourceVisitorIDForKey:key] ?: [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            FTRUMResourceDataModel *resourceStart = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:key];
            resourceStart.time = time;
            NSMutableDictionary *fields = property ? [property mutableCopy] : [NSMutableDictionary dictionary];
            NSDictionary *networkFields = [[FTNetworkConnectivity sharedInstance] networkResourceFields];
            if (networkFields.count > 0) {
                [fields addEntriesFromDictionary:networkFields];
            }
            resourceStart.fields = fields;
            resourceStart.visitorIDSnapshot = visitorID;
            [self process:resourceStart context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    [self addResourceWithKey:key metrics:metrics content:content spanID:nil traceID:nil];
}

- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID{
    if (!key) {
        FTInnerLogError(@"[RUM] Failed to add resource due to missing required fields. Please ensure 'key' are provided.");
        return;
    }
    NSDate *time = [NSDate date];
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            if(metrics.resourceFetchTypeLocalCache && !content.webSocketHandshake){
                FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceAbandon identifier:key];
                resourceSuccess.visitorIDSnapshot = visitorID;
                [self process:resourceSuccess context:context];
            }else{
                NSMutableDictionary *tags = [NSMutableDictionary new];
                NSMutableDictionary *fields = [NSMutableDictionary new];
                NSString *url_path_group = [FTBaseInfoHandler replaceNumberCharByUrl:content.url];
                [tags setValue:content.url.absoluteString forKey:FT_KEY_RESOURCE_URL];
                [tags setValue:content.httpMethod forKey:FT_KEY_RESOURCE_METHOD];
                [tags setValue:content.url.host forKey:FT_KEY_RESOURCE_URL_HOST];
                if(content.url.path.length>0){
                    [tags setValue:content.url.path forKey:FT_KEY_RESOURCE_URL_PATH];
                }
                if(url_path_group.length>0){
                    [tags setValue:url_path_group forKey:FT_KEY_RESOURCE_URL_PATH_GROUP];
                }
                [tags setValue:@(content.httpStatusCode) forKey:FT_KEY_RESOURCE_STATUS];
                
                if (content.error || content.httpStatusCode>=400) {
                    NSString *errorSituation = FTStringFromAppState(self.appState);
                    NSMutableDictionary *errorField = [NSMutableDictionary new];
                    NSMutableDictionary *errorTags = [NSMutableDictionary dictionaryWithDictionary:tags];
                    if(content.error){
                        NSString *errorDescription = [content.error ft_description];
                        [errorField setValue:[NSString stringWithFormat:@"[%@][%@]",[NSString stringWithFormat:@"%ld:%@",(long)content.error.code,errorDescription],content.url.absoluteString] forKey:FT_KEY_ERROR_MESSAGE];
                    }else{
                        [errorField setValue:[NSString stringWithFormat:@"[%ld][%@]",content.httpStatusCode,content.url.absoluteString] forKey:FT_KEY_ERROR_MESSAGE];
                    }
                    [errorTags setValue:FT_NETWORK forKey:FT_KEY_ERROR_SOURCE];
                    [errorTags setValue:FT_NETWORK_ERROR forKey:FT_KEY_ERROR_TYPE];
                    [errorTags setValue:errorSituation forKey:FT_KEY_ERROR_SITUATION];
                    [errorTags addEntriesFromDictionary:[self.rumDependencies.errorMonitorInfoWrapper errorMonitorInfo]];
                    [errorTags setValue:key forKey:FT_KEY_RESOURCE_ID];
                    if (content.responseBody.length>0) {
                        [errorField setValue:content.responseBody forKey:FT_KEY_ERROR_STACK];
                    }
                    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeyRumError message:@{@"error_date":@([time ft_nanosecondTimeStamp]),
                                                                                                 @"error_crash":@(NO)
                                                                                               }];
                    FTRUMResourceModel *resourceError = [[FTRUMResourceModel alloc]initWithType:FTRUMDataResourceError identifier:key];
                    resourceError.time = time;
                    resourceError.tags = errorTags;
                    resourceError.fields = errorField;
                    resourceError.visitorIDSnapshot = visitorID;
                    [self process:resourceError context:context];
                    
                }
                if (!(content.webSocketHandshake && content.httpStatusCode == 0)) {
                    [tags setValue:[self getResourceStatusGroup:content.httpStatusCode] forKey:FT_KEY_RESOURCE_STATUS_GROUP];
                }
                [tags setValue:content.resourceType forKey:FT_KEY_RESOURCE_TYPE];
                if (content.webSocketHandshake) {
                    [tags setValue:FT_RESOURCE_WEBSOCKET_COLLECTION_LEVEL_HANDSHAKE forKey:FT_KEY_RESOURCE_WEBSOCKET_COLLECTION_LEVEL];
                    [tags setValue:content.webSocketHandshakeState forKey:FT_KEY_RESOURCE_WEBSOCKET_HANDSHAKE_STATE];
                }
                [tags setValue:[content.url query] forKey:FT_KEY_RESOURCE_URL_QUERY];
                
                NSNumber *responseSize = metrics.responseSize;
                NSNumber *requestSize = metrics.requestSize;

                if (content.responseHeader) {
                    NSString *responseConnection = content.responseHeader[@"Connection"];
                    NSString *responseConnectType = content.responseHeader[@"Content-Type"];
                    NSString *responseConnectEncoding = content.responseHeader[@"Content-Encoding"];
                    [tags setValue:responseConnection forKey:FT_KEY_RESPONSE_CONNECTION];
                    [tags setValue:responseConnectType forKey:FT_KEY_RESPONSE_CONTENT_TYPE];
                    [tags setValue:responseConnectEncoding forKey:FT_KEY_RESPONSE_CONTENT_ENCODING];
                    NSString *responseHeaderStr = [FTBaseInfoHandler convertToStringData:content.responseHeader];
                    if (!content.webSocketHandshake && responseSize == nil && !metrics.disableHeaderSizeFallback) {
                        responseSize = content.responseHeader[@"Content-Length"];
                        responseSize = @([responseSize longLongValue] + [responseHeaderStr dataUsingEncoding:NSUTF8StringEncoding].length);
                    }
                    [fields setValue:responseHeaderStr forKey:FT_KEY_RESPONSE_HEADER];
                }
                
                if (content.requestHeader) {
                    NSString *requestHeaderStr = [FTBaseInfoHandler convertToStringData:content.requestHeader];
                    [fields setValue:requestHeaderStr forKey:FT_KEY_REQUEST_HEADER];
                    if (!content.webSocketHandshake && requestSize == nil && !metrics.disableHeaderSizeFallback) {
                        requestSize = content.requestHeader[@"Content-Length"];
                        requestSize = @([requestSize longLongValue] + [requestHeaderStr dataUsingEncoding:NSUTF8StringEncoding].length);
                    }
                }
                
                if (!content.webSocketHandshake) {
                    [fields setValue:responseSize forKey:FT_KEY_RESOURCE_SIZE];
                    [fields setValue:requestSize forKey:FT_KEY_RESOURCE_REQUEST_SIZE];
                }

                [fields setValue:metrics.resourceHttpProtocol forKey:FT_KEY_RESOURCE_HTTP_PROTOCOL];
                if (!metrics.connectionReuseUnavailable) {
                    [fields setValue:@(metrics.reusedConnection) forKey:FT_KEY_RESOURCE_CONNECTION_REUSE];
                }
                
                if(self.rumDependencies.enableResourceHostIP){
                    [tags setValue:metrics.remoteAddress forKey:FT_KEY_RESOURCE_HOST_IP];
                }
            
                //add trace info
                [tags setValue:spanID forKey:FT_KEY_SPANID];
                [tags setValue:traceID forKey:FT_KEY_TRACEID];
                
                FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceComplete identifier:key];
                resourceSuccess.metrics = metrics;
                resourceSuccess.time = time;
                resourceSuccess.tags = tags;
                resourceSuccess.fields = fields;
                resourceSuccess.visitorIDSnapshot = visitorID;
                [self process:resourceSuccess context:context];
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
- (NSString *)getResourceStatusGroup:(NSInteger )status{
    if (status>=0 && status<1000) {
        NSInteger a = status/100;
        return  [NSString stringWithFormat:@"%ldxx",(long)a];
    }
    return nil;
}
- (void)stopResourceWithKey:(nonnull NSString *)key {
    [self stopResourceWithKey:key property:nil];
}
- (void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    [self stopResourceWithKey:key property:property time:[NSDate date]];
}
- (void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property time:(NSDate *)time{
    if (!key) {
        FTInnerLogError(@"[RUM] Failed to stop resource due to missing required fields. Please ensure 'key' are provided.");
        return;
    }
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            FTRUMResourceDataModel *resource = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStop identifier:key];
            resource.time = time;
            resource.fields = property;
            resource.visitorIDSnapshot = visitorID;
            [self process:resource context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
    
}


#pragma mark - error / long_task -
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [self addErrorWithType:type stateStr:FTStringFromAppState(self.appState) message:message stack:stack property:nil time:[NSDate ft_currentNanosecondTimeStamp] issueInfo:nil];
}
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property{
    [self addErrorWithType:type stateStr:FTStringFromAppState(self.appState) message:message stack:stack property:property time:[NSDate ft_currentNanosecondTimeStamp] issueInfo:nil];
}
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property{
    [self addErrorWithType:type stateStr:FTStringFromAppState(state) message:message stack:stack property:property time:[NSDate ft_currentNanosecondTimeStamp] issueInfo:nil];
}
- (void)addErrorWithType:(NSString *)type stateStr:(NSString *)stateStr message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property time:(long long)time{
    [self addErrorWithType:type stateStr:stateStr message:message stack:stack property:property time:time issueInfo:nil];
}
- (void)addAutomaticIssueWithCategory:(FTIssueCategory)category
                            errorType:(NSString *)errorType
                             appState:(NSString *)appState
                              message:(nullable NSString *)message
                                stack:(nullable NSString *)stack
                           threadName:(nullable NSString *)threadName
                                 time:(long long)time
                           historical:(BOOL)historical {
    FTIssueInfo *issueInfo = [[FTIssueInfo alloc]
        initWithCategory:category
        errorType:errorType
        message:message
        stack:stack ?: @""
        occurredAtNanoseconds:time
        appState:appState
        threadName:threadName
        historical:historical];
    [self addErrorWithType:errorType
                  stateStr:appState
                   message:message ?: @""
                     stack:stack ?: @""
                  property:nil
                      time:time
                 issueInfo:issueInfo];
}
- (void)addErrorWithType:(NSString *)type
                stateStr:(NSString *)stateStr
                 message:(NSString *)message
                   stack:(NSString *)stack
                property:(nullable NSDictionary *)property
                    time:(long long)time
               issueInfo:(nullable FTIssueInfo *)issueInfo {
    if (!(type && message && type.length>0 && message.length>0)) {
        FTInnerLogError(@"[RUM] Failed to add error due to missing required fields. Please ensure 'type' and 'message' are provided.");
        return;
    }
    [[FTModuleManager sharedInstance] postMessageWithKey:FTMessageKeyRumError message:@{@"error_date":@(time),
                                                                                 @"error_crash":@(NO)
                                                                               } sync:NO];
    NSString *visitorID = [self currentVisitorIDSnapshot];
    [self syncProcess:^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            NSMutableDictionary *fields = [NSMutableDictionary dictionary];
            [fields setValue:stack forKey:FT_KEY_ERROR_STACK];
            [fields setValue:message forKey:FT_KEY_ERROR_MESSAGE];
            if(property && property.allKeys.count>0){
                [fields addEntriesFromDictionary:property];
            }
            NSMutableDictionary *tags = [NSMutableDictionary dictionary];
            [tags setValue:type forKey:FT_KEY_ERROR_TYPE];
            [tags setValue:FT_LOGGER forKey:FT_KEY_ERROR_SOURCE];
            [tags setValue:stateStr forKey:FT_KEY_ERROR_SITUATION];
            [tags addEntriesFromDictionary:[self.rumDependencies.errorMonitorInfoWrapper errorMonitorInfo]];
            if (issueInfo && self.rumDependencies.issueFieldEnricher) {
                NSMutableSet<NSString *> *reservedKeys = [NSMutableSet setWithArray:tags.allKeys];
                [reservedKeys addObjectsFromArray:fields.allKeys];
                [reservedKeys addObjectsFromArray:context.allKeys];
                NSDictionary *customFields =
                    [self.rumDependencies.issueFieldEnricher fieldsForIssue:issueInfo
                                                               reservedKeys:reservedKeys];
                [fields addEntriesFromDictionary:customFields];
            }
            FTRUMErrorData *model = [[FTRUMErrorData alloc]init];
            model.type = FTRUMDataError;
            model.tags = tags;
            model.fields = fields;
            model.tm = time;
            model.visitorIDSnapshot = visitorID;
            [self process:model context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    }];
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration startTime:(long long)time{
    [self addLongTaskWithStack:stack duration:duration startTime:time property:nil];
}
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration startTime:(long long)time property:(nullable NSDictionary *)property{
    if (!stack || (duration == nil)) {
        FTInnerLogError(@"[RUM] Failed to add longtask due to missing required fields. Please ensure 'stack' and 'duration' are provided.");
        return;
    }
    NSString *visitorID = [self currentVisitorIDSnapshot];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            NSMutableDictionary *fields = [NSMutableDictionary dictionary];
            [fields setValue:duration forKey:FT_DURATION];
            [fields setValue:stack forKey:FT_KEY_LONG_TASK_STACK];
            if(property && property.allKeys.count>0){
                [fields addEntriesFromDictionary:property];
            }
            FTRUMDataModel *model = [[FTRUMDataModel alloc]init];
            model.type = FTRUMDataLongTask;
            model.tags = @{};
            model.fields = fields;
            model.tm = time;
            model.visitorIDSnapshot = visitorID;
            [self process:model context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
#pragma mark - webview js -

- (void)addWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (!measurement) {
        return;
    }
    dispatch_async(self.rumQueue, ^{
        @try {
            NSDictionary *context = [self rumDynamicProperty];
            FTRUMWebViewData *webModel = [[FTRUMWebViewData alloc]initWithMeasurement:measurement tm:tm];
            webModel.tags = tags;
            webModel.fields = fields;
            [self process:webModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}

#pragma mark - FTRUMSessionProtocol -
-(BOOL)process:(FTRUMDataModel *)model context:(nonnull NSDictionary *)context{
    if (model.type != FTRUMDataWebViewJSBData) {
        if (model.visitorIDSnapshot.length > 0) {
            NSMutableDictionary *managedContext = [context mutableCopy] ?: [NSMutableDictionary dictionary];
            managedContext[FT_VISITOR_ID] = model.visitorIDSnapshot;
            context = [managedContext copy];
            if (model.tags[FT_VISITOR_ID] != nil) {
                NSMutableDictionary *tags = [model.tags mutableCopy];
                [tags removeObjectForKey:FT_VISITOR_ID];
                model.tags = [tags copy];
            }
            if (model.fields[FT_VISITOR_ID] != nil) {
                NSMutableDictionary *fields = [model.fields mutableCopy];
                [fields removeObjectForKey:FT_VISITOR_ID];
                model.fields = [fields copy];
            }
        }
    }
    FTRUMSessionHandler *current  = self.sessionHandler;
    if (!current && model.type == FTRUMDataAppStateChange) return YES;
    if (current) {
        current.appState = self.appState;
        if ([self manage:self.sessionHandler byPropagatingData:model context:context] == nil) {
            //Refresh
            FTRUMSessionHandler *sessionHandler = [[FTRUMSessionHandler alloc]initWithExpiredSession:self.sessionHandler time:model.time];
            sessionHandler.appState = self.appState;
            self.sessionHandler = sessionHandler;
            [self.sessionHandler.assistant process:model context:context];
        }
    }else{
        //Initialize
        self.sessionHandler = [[FTRUMSessionHandler alloc]initWithModel:model dependencies:self.rumDependencies];
        self.sessionHandler.appState = self.appState;
        [self.sessionHandler.assistant process:model context:context];
    }
    self.rumDependencies.linkRUMSessionContext = [self.sessionHandler getCurrentSessionInfo];
    NSMutableDictionary *snapshot = [[self getCurrentSessionInfo] mutableCopy] ?: [NSMutableDictionary new];
    if (self.sessionHandler) {
        snapshot[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] = @(self.sessionHandler.context.sessionState.sampled_for_error_session);
        if ([snapshot[FT_KEY_VIEW_ID] length] > 0) {
            snapshot[FT_LINK_RUM_KEYS] = self.rumDependencies.lastViewUserCustomDatas;
        }
    }
    [[FTModuleManager sharedInstance] postRUMContext:snapshot source:self];
    return YES;
}
- (void)shutDown {
    [[FTModuleManager sharedInstance] unregisterRUMContextSource:self];
    [[FTModuleManager sharedInstance] removeMessageReceiver:self];
}
-(NSDictionary *)rumDynamicProperty{
    @try {
        return [[FTPresetProperty sharedInstance] rumDynamicTags];        
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
    return @{};
}
- (nullable NSString *)currentVisitorIDSnapshot{
    return [FTVisitorIDManager sharedInstance].snapshot.value;
}
-(void)getLinkRUMDataWithCompletion:(void (^)(NSDictionary * _Nullable))completion{
    dispatch_async(self.rumQueue, ^{
        if (completion) {
            completion(self.rumDependencies.linkRUMSessionContext);
        }
    });
}
-(NSDictionary *)getCurrentSessionInfo{
    return self.rumDependencies.linkRUMSessionContext;
}
#pragma mark ========== FTWKWebViewRumDelegate =============
- (NSString *)getLastHasReplayViewID{
    return self.rumDependencies.sessionHasReplay != nil
        ? self.viewReferrerId
        : nil;
}
-(NSString *)getLastViewName{
    return self.viewReferrer;
}
- (void)dealRUMWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    [self addWebViewData:measurement tags:tags fields:fields tm:tm];
}
- (void)bindSRInfo:(NSDictionary *)info containerViewID:(NSString *)viewID{
    if (viewID && info) {
        NSDictionary *context = [self rumDynamicProperty];
        NSString *visitorID = [self currentVisitorIDSnapshot];
        dispatch_async(self.rumQueue, ^{
            @try {
                FTRUMSRLinkInfoData *model = [[FTRUMSRLinkInfoData alloc]init];
                model.type = FTRUMSRLinkInfo;
                model.tags = @{};
                model.view_id = viewID;
                model.fields = info;
                model.visitorIDSnapshot = visitorID;
                [self process:model context:context];
            } @catch (NSException *exception) {
                FTInnerLogError(@"exception %@",exception);
            }
        });
        
    }
}
- (void)syncProcess{
    [self syncProcess:^{}];
}
- (void)syncProcess:(dispatch_block_t)block{
    if(dispatch_get_specific(FTRUMQueueIdentityKey)==NULL){
        dispatch_sync(self.rumQueue, block);
    }else{
        block();
    }
}
- (void)dealloc{
    self.rumDependencies.appStateHistory.delegate = nil;
    [self.rumDependencies.appStateHistory stopMonitoring];
    [[FTModuleManager sharedInstance] removeMessageReceiver:self];
}
@end
