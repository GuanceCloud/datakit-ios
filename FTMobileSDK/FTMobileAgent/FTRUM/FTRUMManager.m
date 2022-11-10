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
#import "FTPresetProperty.h"
#import "FTThreadDispatchManager.h"
#import "FTLog.h"
#import "FTResourceContentModel.h"
#import "FTGlobalRumManager.h"
#import "FTResourceMetricsModel.h"
@interface FTRUMManager()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
@property (nonatomic, strong) NSMutableDictionary *preViewDuration;
@property (nonatomic, strong) FTRUMMonitor *monitor;
@end
@implementation FTRUMManager

-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig monitor:(FTRUMMonitor *)monitor{
    self = [super init];
    if (self) {
        _rumConfig = rumConfig;
        _appState = AppStateStartUp;
        _preViewDuration = [NSMutableDictionary new];
        _monitor = monitor;
        self.assistant = self;
    }
    return self;
}
#pragma mark - View -
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime{
    [self.preViewDuration setValue:loadTime forKey:viewName];
}
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property{
    [self startViewWithViewID:[NSUUID UUID].UUIDString viewName:viewName property:property];
}
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property{
    NSNumber *duration = @-1;
    if ([self.preViewDuration.allKeys containsObject:viewName]) {
        duration = self.preViewDuration[viewName];
        [self.preViewDuration removeObjectForKey:viewName];
    }
    [self startViewWithViewID:[NSUUID UUID].UUIDString viewName:viewName  loadDuration:duration property:property];

}
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName loadDuration:(NSNumber *)loadDuration property:(nullable NSDictionary *)property{
    if (!(viewId&&viewId.length>0&&viewName&&viewName.length>0)) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewId viewName:viewName viewReferrer:self.viewReferrer];
            viewModel.loading_time = loadDuration?:@0;
            viewModel.type = FTRUMDataViewStart;
            viewModel.fields = property;
            self.viewReferrer = viewName;
            [self process:viewModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}

-(void)stopViewWithProperty:(NSDictionary *)property{
    [self stopViewWithViewID:[self.sessionHandler getCurrentViewID] property:property];
}
-(void)stopViewWithViewID:(NSString *)viewId property:(nullable NSDictionary *)property{
    if (!viewId) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewId viewName:@"" viewReferrer:@""];
            viewModel.type = FTRUMDataViewStop;
            viewModel.fields = property;
            [self process:viewModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - Action -
- (void)addClickActionWithName:(NSString *)actionName property:(NSDictionary *)property{
    [self addActionName:actionName actionType:FT_RUM_KEY_ACTION_TYPE_CLICK property:property];
}
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(NSDictionary *)property{
    if (!actionName || actionName.length == 0 || !actionType || actionType.length == 0) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:actionType];
            actionModel.type = FTRUMDataClick;
            actionModel.fields = property;
            [self process:actionModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration{
    [self addLaunch:isHot duration:duration isPreWarming:NO];
}
- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming{
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSString *actionName = isHot?@"app_hot_start":@"app_cold_start";
            NSString *actionType = isHot?@"launch_hot":@"launch_cold";
            FTRUMDataType type = isHot?FTRUMDataLaunchHot:FTRUMDataLaunchCold;
            FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithType:type duration:duration];
            launchModel.action_name = actionName;
            launchModel.action_type = actionType;
            //启动时是否进行了预热
            launchModel.tags = @{@"active_pre_warm":@(isPreWarming)};
            [self process:launchModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)applicationWillTerminate{
    [FTThreadDispatchManager dispatchSyncInRUMThread:^{
        
    }];
}

#pragma mark - Resource -
- (void)startResource:(NSString *)identifier property:(nullable NSDictionary *)property{
    if (!identifier) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resourceStart = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:identifier];
            resourceStart.fields = property;
            [self process:resourceStart];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)addResource:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
   
    [self addResource:identifier metrics:metrics content:content spanID:nil traceID:nil];
}

- (void)addResource:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(NSString *)spanID traceID:(NSString *)traceID{
    if (!identifier) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        NSMutableDictionary *tags = [NSMutableDictionary new];
        NSMutableDictionary *fields = [NSMutableDictionary new];
        NSString *url_path_group = [FTBaseInfoHandler replaceNumberCharByUrl:content.url];
        [tags setValue:content.url.absoluteString forKey:FT_RUM_KEY_RESOURCE_URL];
        [tags setValue:content.httpMethod forKey:FT_RUM_KEY_RESOURCE_METHOD];
        [tags setValue:content.url.host forKey:FT_RUM_KEY_RESOURCE_URL_HOST];
        if(content.url.path.length>0){
            [tags setValue:content.url.path forKey:FT_RUM_KEY_RESOURCE_URL_PATH];
        }
        if(url_path_group.length>0){
            [tags setValue:url_path_group forKey:FT_RUM_KEY_RESOURCE_URL_PATH_GROUP];
        }
        [tags setValue:@(content.httpStatusCode) forKey:FT_RUM_KEY_RESOURCE_STATUS];
        
        if (content.error || content.httpStatusCode>=400) {
            NSInteger code = content.httpStatusCode >=400?content.httpStatusCode:content.error.code;
            NSString *run = AppStateStringMap[self.appState];
            NSMutableDictionary *errorField = [NSMutableDictionary new];
            NSMutableDictionary *errorTags = [NSMutableDictionary dictionaryWithDictionary:tags];
            [errorField setValue:[NSString stringWithFormat:@"[%ld][%@]",(long)code,content.url.absoluteString] forKey:FT_RUM_KEY_ERROR_MESSAGE];
            [errorTags setValue:FT_RUM_KEY_NETWORK forKey:FT_RUM_KEY_ERROR_SOURCE];
            [errorTags setValue:FT_RUM_KEY_NETWORK forKey:FT_RUM_KEY_ERROR_TYPE];
            [errorTags setValue:run forKey:FT_RUM_KEY_ERROR_SITUATION];
            [errorTags addEntriesFromDictionary:[self errorMonitorInfo]];
            if (content.responseBody.length>0) {
                [errorField setValue:content.responseBody forKey:FT_RUM_KEY_ERROR_STACK];
            }
            [FTThreadDispatchManager dispatchInRUMThread:^{
                FTRUMDataModel *resourceError = [[FTRUMDataModel alloc]initWithType:FTRUMDataResourceError time:time];
                resourceError.time = time;
                resourceError.tags = errorTags;
                resourceError.fields = errorField;
                [self process:resourceError];
            }];
        }
        [tags setValue:[self getResourceStatusGroup:content.httpStatusCode] forKey:FT_RUM_KEY_RESOURCE_STATUS_GROUP];
        
        if([content.responseHeader.allKeys containsObject:@"Content-Length"]){
            NSNumber *size = content.responseHeader[@"Content-Length"];
            [fields setValue:size forKey:FT_RUM_KEY_RESOURCE_SIZE];
        }else if (content.responseBody) {
            NSData *data = [content.responseBody dataUsingEncoding:NSUTF8StringEncoding];
            [fields setValue:@(data.length) forKey:FT_RUM_KEY_RESOURCE_SIZE];
        }
        if(content.responseHeader){
            [tags setValue:[content.url query] forKey:FT_RUM_KEY_RESOURCE_URL_QUERY];
            [tags setValue:content.responseHeader[@"Connection"] forKey:@"response_connection"];
            [tags setValue:content.responseHeader[@"Content-Type"] forKey:@"response_content_type"];
            [tags setValue:content.responseHeader[@"Content-Encoding"] forKey:@"response_content_encoding"];
            [tags setValue:content.responseHeader[@"Content-Type"] forKey:FT_RUM_KEY_RESOURCE_TYPE];
            [fields setValue:[FTBaseInfoHandler convertToStringData:content.responseHeader] forKey:@"response_header"];
        }
        [fields setValue:[FTBaseInfoHandler convertToStringData:content.requestHeader] forKey:@"request_header"];
        //add trace info
            [tags setValue:spanID forKey:FT_KEY_SPANID];
            [tags setValue:traceID forKey:FT_KEY_TRACEID];
    
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceComplete identifier:identifier];
            resourceSuccess.metrics = metrics;
            resourceSuccess.time = time;
            resourceSuccess.tags = tags;
            resourceSuccess.fields = fields;
            [self process:resourceSuccess];
        }];
        
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (NSString *)getResourceStatusGroup:(NSInteger )status{
    if (status>=0 && status<1000) {
        NSInteger a = status/100;
        return  [NSString stringWithFormat:@"%ldxx",(long)a];
    }
    return nil;
}
- (void)stopResource:(NSString *)identifier{
    [self stopResourceWithKey:identifier property:nil];
}
- (void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    if (!key) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resource = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStop identifier:key];
            resource.fields = property;
            [self process:resource];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - error 、 long_task -
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property{
    if (!(type && message && stack && type.length>0 && message.length>0 && stack.length>0)) {
        return;
    }
    @try {
        NSMutableDictionary *field = @{ FT_RUM_KEY_ERROR_MESSAGE:message,
                                 FT_RUM_KEY_ERROR_STACK:stack,
        }.mutableCopy;
        if(property && property.allKeys.count>0){
            [field addEntriesFromDictionary:property];
        }
        NSDictionary *tags = @{
            FT_RUM_KEY_ERROR_TYPE:type,
            FT_RUM_KEY_ERROR_SOURCE:@"logger",
            FT_RUM_KEY_ERROR_SITUATION:AppStateStringMap[self.appState]
        };
        NSMutableDictionary *errorTag = [NSMutableDictionary dictionaryWithDictionary:tags];
        [errorTag addEntriesFromDictionary:[self errorMonitorInfo]];
        [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
            FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataError time:[NSDate date]];
            model.tags = errorTag;
            model.fields = field;
            [self process:model];
        }];
        
        [FTThreadDispatchManager dispatchSyncInRUMThread:^{
            
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(nullable NSDictionary *)property{
    if (!stack || stack.length == 0 || !duration) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSMutableDictionary *fields = @{FT_DURATION:duration,
                                     FT_RUM_KEY_LONG_TASK_STACK:stack
            }.mutableCopy;
            if(property && property.allKeys.count>0){
                [fields addEntriesFromDictionary:property];
            }
            FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataLongTask time:[NSDate date]];
            model.tags = @{};
            model.fields = fields;
            [self process:model];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
    
}
- (NSDictionary *)errorMonitorInfo{
    NSMutableDictionary *errorTag = [NSMutableDictionary new];
    FTErrorMonitorType monitorType = self.rumConfig.errorMonitorType;
    if (monitorType & FTErrorMonitorMemory) {
        errorTag[FT_MONITOR_MEMORY_TOTAL] = [FTMonitorUtils totalMemorySize];
        errorTag[FT_MONITOR_MEM_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils usedMemory]];
    }
    if (monitorType & FTErrorMonitorCpu) {
        errorTag[FT_MONITOR_CPU_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils cpuUsage]];
    }
    if (monitorType & FTErrorMonitorBattery) {
        errorTag[FT_MONITOR_POWER] =[NSNumber numberWithDouble:[FTMonitorUtils batteryUse]];
    }
    errorTag[@"carrier"] = [FTPresetProperty telephonyInfo];
    NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    errorTag[@"locale"] = preferredLanguage;
    return errorTag;
}
#pragma mark - webview js -

- (void)addWebviewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    if (!measurement) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMWebViewData *webModel = [[FTRUMWebViewData alloc]initWithMeasurement:measurement tm:tm];
            webModel.tags = tags;
            webModel.fields = fields;
            [self process:webModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}

#pragma mark - FTRUMSessionProtocol -
-(BOOL)process:(FTRUMDataModel *)model{
    FTRUMSessionHandler *current  = self.sessionHandler;
    if (current) {
        if ([self manage:self.sessionHandler byPropagatingData:model] == nil) {
            //刷新
            [self.sessionHandler refreshWithDate:model.time];
            [self.sessionHandler.assistant process:model];
        }
    }else{
        //初始化
        self.sessionHandler = [[FTRUMSessionHandler alloc]initWithModel:model rumConfig:self.rumConfig monitor:self.monitor];
        [self.sessionHandler.assistant process:model];
    }
    
    return YES;
}

-(NSDictionary *)getCurrentSessionInfo{
    return [self.sessionHandler getCurrentSessionInfo];
}
- (void)syncProcess{
    [FTThreadDispatchManager dispatchSyncInRUMThread:^{
        
    }];
}
@end

