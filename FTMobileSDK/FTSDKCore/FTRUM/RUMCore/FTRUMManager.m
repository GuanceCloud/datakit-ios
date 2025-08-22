//
//  FTRUMManger.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTRUMManager.h"
#import "FTBaseInfoHandler.h"
#import "FTRUMSessionHandler.h"
#import "FTMonitorUtils.h"
#import "FTLog+Private.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTSDKCompat.h"
#import "FTConstants.h"
#import "FTErrorMonitorInfo.h"
#import "FTReadWriteHelper.h"
#import "NSError+FTDescription.h"
#import "FTPresetProperty.h"
#import "FTNetworkConnectivity.h"

NSString * const AppStateStringMap[] = {
    [FTAppStateUnknown] = @"unknown",
    [FTAppStateStartUp] = @"startup",
    [FTAppStateRun] = @"run",
};
void *FTRUMQueueIdentityKey = &FTRUMQueueIdentityKey;

@interface FTRUMManager()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMDependencies *rumDependencies;
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
@property (nonatomic, strong) FTReadWriteHelper<NSMutableDictionary *> *preViewDuration;
@property (nonatomic, strong) dispatch_queue_t rumQueue;
@end
@implementation FTRUMManager
-(instancetype)initWithRumDependencies:(FTRUMDependencies *)dependencies{
    self = [super init];
    if(self){
        _rumDependencies = dependencies;
        _appState = FTAppStateStartUp;
        _preViewDuration = [[FTReadWriteHelper alloc]initWithValue:[NSMutableDictionary new]] ;
        _rumQueue = dispatch_queue_create("com.ft.rum", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_rumQueue, FTRUMQueueIdentityKey, &FTRUMQueueIdentityKey, NULL);
        [self notifyRumInit];
        self.assistant = self;
    }
    return self;
}
-(void)setAppState:(FTAppState)appState{
    _appState = appState;
    self.rumDependencies.fatalErrorContext.appState = AppStateStringMap[appState];
}
#pragma mark - Session -
-(void)notifyRumInit{
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMDataModel *model = [[FTRUMDataModel alloc]init];
            model.type = FTRUMSDKInit;
            [self process:model context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
#pragma mark - View -
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime{
    [self.preViewDuration concurrentWrite:^(NSMutableDictionary * _Nonnull value) {
        [value setValue:loadTime forKey:viewName];
    }];
}
-(void)startViewWithName:(NSString *)viewName{
    [self startViewWithName:viewName property:nil];
}
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property{
    [self startViewWithViewID:[FTBaseInfoHandler randomUUID] viewName:viewName property:property];
}
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property{
    __block NSNumber *duration = @0;
    if (!(viewId&&viewId.length>0&&viewName&&viewName.length>0)) {
        FTInnerLogError(@"[RUM] Failed to start view due to missing required fields. Please ensure 'viewName' are provided.");
        return;
    }
    [self.preViewDuration concurrentRead:^(NSMutableDictionary * _Nonnull value) {
        if ([value.allKeys containsObject:viewName]) {
            duration = value[viewName];
            [value removeObjectForKey:viewName];
        }
    }];
    
    NSDate *time = [NSDate date];
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewId viewName:viewName viewReferrer:self.viewReferrer];
            viewModel.time = time;
            viewModel.loading_time = duration?:@0;
            viewModel.type = FTRUMDataViewStart;
            viewModel.fields = property;
            self.viewReferrer = viewName;
            [self process:viewModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
-(void)updateViewLoadingTime:(NSNumber *)duration{
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMViewLoadingModel *viewModel = [[FTRUMViewLoadingModel alloc]initWithDuration:duration];
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
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            NSString *stopViewId = viewId?viewId:[self.sessionHandler getCurrentViewID];
            if(!stopViewId){
                return;
            }
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:stopViewId viewName:@"" viewReferrer:@""];
            viewModel.time = time;
            viewModel.type = FTRUMDataViewStop;
            viewModel.fields = property;
            [self process:viewModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
#pragma mark - Action -
- (void)startAction:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    NSDate *time = [NSDate date];
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:actionType];
            actionModel.time = time;
            actionModel.type = FTRUMDataStartAction;
            actionModel.fields = property;
            [self process:actionModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
- (void)addAction:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    NSDate *time = [NSDate date];
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:actionType];
            actionModel.time = time;
            actionModel.type = FTRUMDataAddAction;
            actionModel.fields = property;
            [self process:actionModel context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
}
- (void)addLaunch:(NSString *)name type:(NSString *)type launchTime:(NSDate *)time duration:(NSNumber *)duration property:(nullable NSDictionary *)property{
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithDuration:duration];
            launchModel.time = time;
            launchModel.action_name = name;
            launchModel.action_type = type;
            launchModel.fields = property;
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
    if (!key) {
        FTInnerLogError(@"[RUM] Failed to start resource due to missing required fields. Please ensure 'key' are provided.");
        return;
    }
    NSDate *time = [NSDate date];
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMResourceDataModel *resourceStart = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:key];
            resourceStart.time = time;
            resourceStart.fields = property;
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
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            if(metrics.resourceFetchTypeLocalCache){
                FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceAbandon identifier:key];
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
                    NSString *run = AppStateStringMap[self.appState];
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
                    [errorTags setValue:run forKey:FT_KEY_ERROR_SITUATION];
                    [errorTags addEntriesFromDictionary:[FTErrorMonitorInfo errorMonitorInfo:self.rumDependencies.errorMonitorType]];
                    if (content.responseBody.length>0) {
                        [errorField setValue:content.responseBody forKey:FT_KEY_ERROR_STACK];
                    }
                    
                    FTRUMResourceModel *resourceError = [[FTRUMResourceModel alloc]initWithType:FTRUMDataResourceError identifier:key];
                    resourceError.time = time;
                    resourceError.tags = errorTags;
                    resourceError.fields = errorField;
                    [self process:resourceError context:context];
                    
                }
                [tags setValue:[self getResourceStatusGroup:content.httpStatusCode] forKey:FT_KEY_RESOURCE_STATUS_GROUP];
                [tags setValue:FT_NETWORK forKey:FT_KEY_RESOURCE_TYPE];
                [tags setValue:[content.url query] forKey:FT_KEY_RESOURCE_URL_QUERY];
                if(content.responseHeader){
                    for (id key in content.responseHeader.allKeys) {
                        if([key isKindOfClass:NSString.class]){
                            NSString *lowercaseKey = [(NSString *)key lowercaseString];
                            if([lowercaseKey isEqualToString:@"connection"]){
                                [tags setValue:content.responseHeader[key] forKey:FT_KEY_RESPONSE_CONNECTION];
                            }else if ([lowercaseKey isEqualToString:@"content-type"]){
                                [tags setValue:content.responseHeader[key] forKey:FT_KEY_RESPONSE_CONTENT_TYPE];
                            }else if([lowercaseKey isEqualToString:@"content-encoding"]){
                                [tags setValue:content.responseHeader[key] forKey:FT_KEY_RESPONSE_CONTENT_ENCODING];
                            }
                        }
                    }
                    [fields setValue:[FTBaseInfoHandler convertToStringData:content.responseHeader] forKey:FT_KEY_RESPONSE_HEADER];
                }
                if(metrics.responseSize!=nil){
                    [fields setValue:metrics.responseSize forKey:FT_KEY_RESOURCE_SIZE];
                }else if(content.responseBody){
                    NSData *data = [content.responseBody dataUsingEncoding:NSUTF8StringEncoding];
                    [fields setValue:@(data.length) forKey:FT_KEY_RESOURCE_SIZE];
                }
                [fields setValue:[FTBaseInfoHandler convertToStringData:content.requestHeader] forKey:FT_KEY_REQUEST_HEADER];
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
    if (!key) {
        FTInnerLogError(@"[RUM] Failed to stop resource due to missing required fields. Please ensure 'key' are provided.");
        return;
    }
    NSDate *time = [NSDate date];
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
            FTRUMResourceDataModel *resource = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStop identifier:key];
            resource.time = time;
            resource.fields = property;
            [self process:resource context:context];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception %@",exception);
        }
    });
    
}


#pragma mark - error 、 long_task -
- (void)internalErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [self addErrorWithType:type state:self.appState message:message stack:stack property:nil time:[NSDate date] fatal:YES];
}
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property{
    [self addErrorWithType:type state:state message:message stack:stack property:property time:[NSDate date] fatal:YES];
}
- (void)addErrorWithType:(nonnull NSString *)type message:(nonnull NSString *)message stack:(nonnull NSString *)stack date:(NSDate *)date{
    [self addErrorWithType:type state:self.appState message:message stack:stack property:nil time:date fatal:NO];
}
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [self addErrorWithType:type state:self.appState message:message stack:stack property:nil time:[NSDate date] fatal:NO];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property{
    [self addErrorWithType:type state:self.appState message:message stack:stack property:property time:[NSDate date] fatal:NO];
}
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property time:(NSDate *)time fatal:(BOOL)fatal{
    if (!(type && message && type.length>0 && message.length>0)) {
        FTInnerLogError(@"[RUM] Failed to add error due to missing required fields. Please ensure 'type'、'message' are provided.");
        return;
    }
    NSDictionary *context = [self rumDynamicProperty];
    [self syncProcess:^{
      @try {
        NSMutableDictionary *fields = [NSMutableDictionary dictionary];
        [fields setValue:stack forKey:FT_KEY_ERROR_STACK];
        [fields setValue:message forKey:FT_KEY_ERROR_MESSAGE];
        if(property && property.allKeys.count>0){
          [fields addEntriesFromDictionary:property];
        }
        NSMutableDictionary *tags = [NSMutableDictionary dictionary];
        [tags setValue:type forKey:FT_KEY_ERROR_TYPE];
        [tags setValue:FT_LOGGER forKey:FT_KEY_ERROR_SOURCE];
        [tags setValue:AppStateStringMap[state] forKey:FT_KEY_ERROR_SITUATION];
        [tags addEntriesFromDictionary:[FTErrorMonitorInfo errorMonitorInfo:self.rumDependencies.errorMonitorType]];
        FTRUMErrorData *model = [[FTRUMErrorData alloc]initWithType:FTRUMDataError time:time];
        model.tags = tags;
        model.fields = fields;
        model.fatal = fatal;
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
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
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
    NSDictionary *context = [self rumDynamicProperty];
    dispatch_async(self.rumQueue, ^{
        @try {
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
    FTRUMSessionHandler *current  = self.sessionHandler;
    if (current) {
        if ([self manage:self.sessionHandler byPropagatingData:model context:context] == nil) {
            //Refresh
            FTRUMSessionHandler *sessionHandler = [[FTRUMSessionHandler alloc]initWithExpiredSession:self.sessionHandler time:model.time];
            self.sessionHandler = sessionHandler;
            [self.sessionHandler.assistant process:model context:context];
        }
    }else{
        //Initialize
        self.sessionHandler = [[FTRUMSessionHandler alloc]initWithModel:model dependencies:self.rumDependencies];
        [self.sessionHandler.assistant process:model context:context];
    }
    
    return YES;
}
-(NSDictionary *)rumDynamicProperty{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    @try {
        dict[@"network_type"] = [FTNetworkConnectivity sharedInstance].networkType;
        [dict addEntriesFromDictionary:[[FTPresetProperty sharedInstance] rumDynamicTags]];
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    } @finally {
        return dict;
    }
}
- (NSDictionary *)getLinkRUMData{
    if(self.rumDependencies.currentSessionSample){
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict addEntriesFromDictionary:[self rumDynamicProperty]];
        [dict addEntriesFromDictionary:self.rumDependencies.fatalErrorContext.lastSessionContext];
        return dict;
    }
    return nil;
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
@end

