//
//  FTRUMManger.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTRUMManager.h"
#import "FTBaseInfoHandler.h"
#import "FTRUMSessionHandler.h"
#import "FTMonitorUtils.h"
#import "FTInternalLog.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
#import "FTSDKCompat.h"
#import "FTConstants.h"
NSString * const AppStateStringMap[] = {
    [FTAppStateUnknown] = @"unknown",
    [FTAppStateStartUp] = @"startup",
    [FTAppStateRun] = @"run",
};
@interface FTRUMManager()<FTRUMSessionProtocol>
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) ErrorMonitorType errorMonitorType;
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
@property (nonatomic, strong) NSMutableDictionary *preViewDuration;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@property (nonatomic, weak) id<FTRUMDataWriteProtocol> writer;
@property (nonatomic, strong) dispatch_queue_t rumQueue;
@end
@implementation FTRUMManager

-(instancetype)initWithRumSampleRate:(int)sampleRate errorMonitorType:(ErrorMonitorType)errorMonitorType monitor:(nullable FTRUMMonitor *)monitor writer:(id<FTRUMDataWriteProtocol>)writer{
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        _errorMonitorType = errorMonitorType;
        _appState = FTAppStateStartUp;
        _preViewDuration = [NSMutableDictionary new];
        _monitor = monitor;
        _writer = writer;
        _rumQueue = dispatch_queue_create_with_target("com.guance.rum", DISPATCH_QUEUE_SERIAL, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        self.assistant = self;
    }
    return self;
}
#pragma mark - View -
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime{
    [self.preViewDuration setValue:loadTime forKey:viewName];
}
-(void)startViewWithName:(NSString *)viewName{
    [self startViewWithName:viewName property:nil];
}
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property{
    [self startViewWithViewID:[FTBaseInfoHandler randomUUID] viewName:viewName property:property];
}
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property{
    NSNumber *duration = @0;
    if (!(viewId&&viewId.length>0&&viewName&&viewName.length>0)) {
        return;
    }
    if ([self.preViewDuration.allKeys containsObject:viewName]) {
        duration = self.preViewDuration[viewName];
        [self.preViewDuration removeObjectForKey:viewName];
    }
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewId viewName:viewName viewReferrer:self.viewReferrer];
            viewModel.time = time;
            viewModel.loading_time = duration?:@0;
            viewModel.type = FTRUMDataViewStart;
            viewModel.fields = property;
            self.viewReferrer = viewName;
            [self process:viewModel];
        });
        
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
-(void)stopView{
    [self stopViewWithViewID:nil property:nil];
}
-(void)stopViewWithProperty:(NSDictionary *)property{
    [self stopViewWithViewID:nil property:property];
}
-(void)stopViewWithViewID:(NSString *)viewId property:(nullable NSDictionary *)property{
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
            NSString *stopViewId = viewId?viewId:[self.sessionHandler getCurrentViewID];
            if(!stopViewId){
                return;
            }
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:stopViewId viewName:@"" viewReferrer:@""];
            viewModel.time = time;
            viewModel.type = FTRUMDataViewStop;
            viewModel.fields = property;
            [self process:viewModel];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
#pragma mark - Action -
-(void)addClickActionWithName:(NSString *)actionName{
    [self addClickActionWithName:actionName property:nil];
}
- (void)addClickActionWithName:(NSString *)actionName property:(NSDictionary *)property{
    [self addActionName:actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:property];
}
-(void)addActionName:(NSString *)actionName actionType:(NSString *)actionType{
    [self addActionName:actionName actionType:actionType property:nil];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    if (!actionName || actionName.length == 0 || !actionType || actionType.length == 0) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:actionType];
            actionModel.time = time;
            actionModel.type = FTRUMDataClick;
            actionModel.fields = property;
            [self process:actionModel];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)addLaunch:(FTLaunchType)type duration:(NSNumber *)duration{
    self.appState = FTAppStateRun;
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
            NSString *actionName;
            NSString *actionType;
            switch (type) {
                case FTLaunchHot:
                    actionName = @"app_hot_start";
                    actionType = @"launch_hot";
                    break;
                case FTLaunchCold:
                    actionName = @"app_cold_start";
                    actionType = @"launch_cold";
                    break;
                case FTLaunchWarm:
                    actionName = @"app_warm_start";
                    actionType = @"launch_warm";
                    break;
            }
            FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithDuration:duration];
            launchModel.time = time;
            launchModel.action_name = actionName;
            launchModel.action_type = actionType;
            
            [self process:launchModel];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}

#pragma mark - Resource -
-(void)startResourceWithKey:(NSString *)key{
    [self startResourceWithKey:key property:nil];
}
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property{
    if (!key) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
            FTRUMResourceDataModel *resourceStart = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:key];
            resourceStart.time = time;
            resourceStart.fields = property;
            [self process:resourceStart];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    [self addResourceWithKey:key metrics:metrics content:content spanID:nil traceID:nil];
}

- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID{
    if (!key) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
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
                   [errorField setValue:[NSString stringWithFormat:@"[%@][%@]",[NSString stringWithFormat:@"%ld:%@",(long)content.error.code,content.error.localizedDescription],content.url.absoluteString] forKey:FT_KEY_ERROR_MESSAGE];
                }else{
                   [errorField setValue:[NSString stringWithFormat:@"[%ld][%@]",content.httpStatusCode,content.url.absoluteString] forKey:FT_KEY_ERROR_MESSAGE];
                }
                [errorTags setValue:FT_NETWORK forKey:FT_KEY_ERROR_SOURCE];
                [errorTags setValue:FT_NETWORK forKey:FT_KEY_ERROR_TYPE];
                [errorTags setValue:run forKey:FT_KEY_ERROR_SITUATION];
                [errorTags addEntriesFromDictionary:[self errorMonitorInfo]];
                if (content.responseBody.length>0) {
                    [errorField setValue:content.responseBody forKey:FT_KEY_ERROR_STACK];
                }
                
                FTRUMResourceModel *resourceError = [[FTRUMResourceModel alloc]initWithType:FTRUMDataResourceError identifier:key];
                resourceError.time = time;
                resourceError.tags = errorTags;
                resourceError.fields = errorField;
                [self process:resourceError];
                
            }
            [tags setValue:[self getResourceStatusGroup:content.httpStatusCode] forKey:FT_KEY_RESOURCE_STATUS_GROUP];
            [tags setValue:FT_NETWORK forKey:FT_KEY_RESOURCE_TYPE];
            
            if(content.responseHeader){
                [tags setValue:[content.url query] forKey:FT_KEY_RESOURCE_URL_QUERY];
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
                if(metrics.responseSize){
                    [fields setValue:metrics.responseSize forKey:FT_KEY_RESOURCE_SIZE];
                }else if(content.responseBody){
                    NSData *data = [content.responseBody dataUsingEncoding:NSUTF8StringEncoding];
                    [fields setValue:@(data.length) forKey:FT_KEY_RESOURCE_SIZE];
                }
                [fields setValue:[FTBaseInfoHandler convertToStringData:content.responseHeader] forKey:FT_KEY_RESPONSE_HEADER];
            }
            [fields setValue:[FTBaseInfoHandler convertToStringData:content.requestHeader] forKey:FT_KEY_REQUEST_HEADER];
            //add trace info
            [tags setValue:spanID forKey:FT_KEY_SPANID];
            [tags setValue:traceID forKey:FT_KEY_TRACEID];
            
            FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceComplete identifier:key];
            resourceSuccess.metrics = metrics;
            resourceSuccess.time = time;
            resourceSuccess.tags = tags;
            resourceSuccess.fields = fields;
            [self process:resourceSuccess];
        });
        
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
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
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
            FTRUMResourceDataModel *resource = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStop identifier:key];
            resource.time = time;
            resource.fields = property;
            [self process:resource];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}


#pragma mark - error 、 long_task -
- (void)internalErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [self addErrorWithType:type state:self.appState message:message stack:stack property:nil fatal:YES];
}
-(void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack{
    [self addErrorWithType:type state:self.appState message:message stack:stack property:nil fatal:NO];
}
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property{
    [self addErrorWithType:type state:self.appState message:message stack:stack property:property fatal:NO];
}
- (void)addErrorWithType:(nonnull NSString *)type state:(FTAppState)state message:(nonnull NSString *)message stack:(nonnull NSString *)stack property:(nullable NSDictionary *)property{
    [self addErrorWithType:type state:state message:message stack:stack property:property fatal:NO];
}
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property fatal:(BOOL)fatal{
    if (!(type && message && stack && type.length>0 && message.length>0 && stack.length>0)) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        dispatch_sync(self.rumQueue, ^{
            NSMutableDictionary *field = @{ FT_KEY_ERROR_MESSAGE:message,
                                            FT_KEY_ERROR_STACK:stack,
            }.mutableCopy;
            if(property && property.allKeys.count>0){
                [field addEntriesFromDictionary:property];
            }
            NSDictionary *tags = @{
                FT_KEY_ERROR_TYPE:type,
                FT_KEY_ERROR_SOURCE:FT_LOGGER,
                FT_KEY_ERROR_SITUATION:AppStateStringMap[state]
            };
            NSMutableDictionary *errorTag = [NSMutableDictionary dictionaryWithDictionary:tags];
            [errorTag addEntriesFromDictionary:[self errorMonitorInfo]];
            FTRUMErrorData *model = [[FTRUMErrorData alloc]initWithType:FTRUMDataError time:time];
            model.tags = errorTag;
            model.fields = field;
            model.fatal = fatal;
            [self process:model];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
-(void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    [self addLongTaskWithStack:stack duration:duration property:nil];
}
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(nullable NSDictionary *)property{
    if (!stack || stack.length == 0 || (duration == nil)) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        dispatch_async(self.rumQueue, ^{
            NSMutableDictionary *fields = @{FT_DURATION:duration,
                                            FT_KEY_LONG_TASK_STACK:stack
            }.mutableCopy;
            if(property && property.allKeys.count>0){
                [fields addEntriesFromDictionary:property];
            }
            FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataLongTask time:time];
            model.tags = @{};
            model.fields = fields;
            [self process:model];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
    
}
- (NSDictionary *)errorMonitorInfo{
    NSMutableDictionary *errorTag = [NSMutableDictionary new];
    ErrorMonitorType monitorType = self.errorMonitorType;
    if (monitorType & ErrorMonitorMemory) {
        errorTag[FT_MEMORY_TOTAL] = [FTMonitorUtils totalMemorySize];
        errorTag[FT_MEMORY_USE] = [NSNumber numberWithFloat:[FTMonitorUtils usedMemory]];
    }
    if (monitorType & ErrorMonitorCpu) {
        errorTag[FT_CPU_USE] = [NSNumber numberWithLong:[FTMonitorUtils cpuUsage]];
    }
    if (monitorType & ErrorMonitorBattery) {
        errorTag[FT_BATTERY_USE] =[NSNumber numberWithDouble:[FTMonitorUtils batteryUse]];
    }
#if FT_IOS
    errorTag[FT_KEY_CARRIER] = [FTBaseInfoHandler telephonyCarrier];
#endif
    NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    errorTag[FT_KEY_LOCALE] = preferredLanguage;
    return errorTag;
}
#pragma mark - webview js -

- (void)addWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (!measurement) {
        return;
    }
    @try {
        dispatch_async(self.rumQueue, ^{
            FTRUMWebViewData *webModel = [[FTRUMWebViewData alloc]initWithMeasurement:measurement tm:tm];
            webModel.tags = tags;
            webModel.fields = fields;
            [self process:webModel];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}

#pragma mark - FTRUMSessionProtocol -
-(BOOL)process:(FTRUMDataModel *)model{
    FTRUMSessionHandler *current  = self.sessionHandler;
    if (current) {
        if ([self manage:self.sessionHandler byPropagatingData:model] == nil) {
            //刷新
            FTRUMSessionHandler *sessionHandler = [[FTRUMSessionHandler alloc]initWithExpiredSession:self.sessionHandler time:model.time];
            self.sessionHandler = sessionHandler;
            [self.sessionHandler.assistant process:model];
        }
    }else{
        //初始化
        self.sessionHandler = [[FTRUMSessionHandler alloc]initWithModel:model sampleRate:self.sampleRate monitor:self.monitor writer:self.writer];
        [self.sessionHandler.assistant process:model];
    }
    
    return YES;
}

-(NSDictionary *)getCurrentSessionInfo{
    return [self.sessionHandler getCurrentSessionInfo];
}
- (void)syncProcess{
    dispatch_sync(self.rumQueue, ^{});
}
@end

