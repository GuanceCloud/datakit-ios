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
#import "UIViewController+FTAutoTrack.h"
#import "FTMonitorUtils.h"
#import "FTPresetProperty.h"
#import "FTThreadDispatchManager.h"
#import "FTLog.h"
#import "FTResourceContentModel.h"
#import "FTConfigManager.h"
#import "FTMonitorManager.h"
#import "FTResourceMetricsModel.h"
@interface FTRUMManager()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;

@end
@implementation FTRUMManager

-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig{
    self = [super init];
    if (self) {
        self.rumConfig = rumConfig;
        self.assistant = self;
    }
    return self;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = rumConfig;
}
#pragma mark - View -
-(void)startViewWithName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer loadDuration:(NSNumber *)loadDuration{
    [self startViewWithViewID:[NSUUID UUID].UUIDString viewName:viewName viewReferrer:viewReferrer loadDuration:loadDuration];
}
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName viewReferrer:(NSString *)viewReferrer loadDuration:(NSNumber *)loadDuration{
    if (!(viewId&&viewName&&viewReferrer)) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewId viewName:viewName viewReferrer:viewReferrer];
            viewModel.loading_time = loadDuration?:@0;
            viewModel.type = FTRUMDataViewStart;
            [self process:viewModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}

-(void)stopView{
    NSString *viewID = [self.sessionHandler getCurrentViewID]?:[NSUUID UUID].UUIDString;
    [self stopViewWithViewID:viewID];
}
-(void)stopViewWithViewID:(NSString *)viewId{
    if (!viewId) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewId viewName:@"" viewReferrer:@""];
            viewModel.type = FTRUMDataViewStop;
            [self process:viewModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - Action -
- (void)addClickActionWithName:(NSString *)actionName{
    if (!actionName) {
        return;
    }
    if (!self.rumConfig.enableTraceUserAction) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc] initWithActionName:actionName actionType:@"click"];
            actionModel.type = FTRUMDataClick;
            [self process:actionModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)addLaunch:(BOOL)isHot duration:(NSNumber *)duration{
    if (!self.rumConfig.enableTraceUserAction) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSString *actionName = isHot?@"app_hot_start":@"app_cold_start";
            NSString *actionType = isHot?@"launch_hot":@"launch_cold";
            FTRUMDataType type = isHot?FTRUMDataLaunchHot:FTRUMDataLaunchCold;
            FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithType:type duration:duration];
            launchModel.action_name = actionName;
            launchModel.action_type = actionType;
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
- (void)startResource:(NSString *)identifier{
    if (!identifier) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resourceStart = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:identifier];
            
            [self process:resourceStart];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)addResourceMetrics:(NSString *)identifier metrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    if (!identifier) {
        return;
    }
    FTResourceMetricsModel *model = [[FTResourceMetricsModel alloc]initWithTaskMetrics:metrics];
    [self addResourceMetricsModel:identifier model:model];
}
- (void)addResourceMetricsModel:(NSString *)identifier model:(FTResourceMetricsModel *)model{
    if (!identifier) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceMetricsModel *metricsModel = [[FTRUMResourceMetricsModel alloc]initWithType:FTRUMDataResourceMetrics identifier:identifier];
            metricsModel.metrics = model;
            [self process:metricsModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)stopResource:(NSString *)identifier content:(FTResourceContentModel *)model spanID:(NSString *)spanID traceID:(NSString *)traceID{
    if (!identifier) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        NSMutableDictionary *tags = [NSMutableDictionary new];
        NSMutableDictionary *fields = [NSMutableDictionary new];
        NSString *url_path_group = [FTBaseInfoHandler replaceNumberCharByUrl:model.url];
        [tags setValue:model.url.absoluteString forKey:@"resource_url"];
        [tags setValue:model.url.host forKey:@"resource_url_host"];
        [tags setValue:model.url.path forKey:@"resource_url_path"];
        [tags setValue:url_path_group forKey:@"resource_url_path_group"];
        [tags setValue:@(model.httpStatusCode) forKey:@"resource_status"];
        [tags setValue:[self getResourceStatusGroup:model.httpStatusCode] forKey:@"resource_status_group"];
        [fields setValue:@0 forKey:@"resource_size"];
        if (model.responseBody) {
            NSData *data = [model.responseBody dataUsingEncoding:NSUTF8StringEncoding];
            [fields setValue:@(data.length) forKey:@"resource_size"];
        }
        if ([FTConfigManager sharedInstance].traceConfig.enableLinkRumData) {
            [tags setValue:spanID forKey:@"span_id"];
            [tags setValue:traceID forKey:@"trace_id"];
        }
    if (model.error || model.httpStatusCode>=400) {
        NSInteger code = model.httpStatusCode == -1?:model.error.code;
        NSString *run = AppStateStringMap[[FTMonitorManager sharedInstance].running];
        [fields setValue:[NSString stringWithFormat:@"[%ld][%@]",(long)code,model.url.absoluteString] forKey:@"error_message"];
               [tags setValue:run forKey:@"error_situation"];
        [tags setValue:model.resourceMethod forKey:@"resource_method"];
        [tags setValue:@(model.httpStatusCode) forKey:@"resource_status"];
        [tags setValue:@"network" forKey:@"error_source"];
        [tags setValue:@"network" forKey:@"error_type"];
        if (model.responseBody.length>0) {
            [fields setValue:model.responseBody forKey:@"error_stack"];
        }
        [self resourceError:identifier tags:tags fields:fields time:time];
    }else{
       
        [tags setValue:[model.url query] forKey:@"resource_url_query"];
        [tags setValue:model.resourceMethod forKey:@"resource_method"];
        [tags setValue:model.responseHeader[@"Connection"] forKey:@"response_connection"];
        [tags setValue:model.responseHeader[@"Content-Type"] forKey:@"response_content_type"];
        [tags setValue:model.responseHeader[@"Content-Encoding"] forKey:@"response_content_encoding"];
        [tags setValue:model.responseHeader[@"Content-Type"] forKey:@"resource_type"];
        [fields setValue:[FTBaseInfoHandler convertToStringData:model.requestHeader] forKey:@"request_header"];
        [fields setValue:[FTBaseInfoHandler convertToStringData:model.responseHeader] forKey:@"response_header"];

        [self resourceSuccess:identifier tags:tags fields:fields time:time];

    }
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
- (void)resourceSuccess:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time{
    if (!identifier) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStop identifier:identifier];
            resourceSuccess.time = time;
            resourceSuccess.tags = tags;
            resourceSuccess.fields = fields;
            [self process:resourceSuccess];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)resourceError:(NSString *)identifier tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(NSDate *)time{
    if (!identifier) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resourceError = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStopWithError identifier:identifier];
            NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:[self errorMonitorInfo]];
            [newTags addEntriesFromDictionary:tags];
            resourceError.time = time;
            resourceError.tags = newTags;
            resourceError.fields = fields;
            [self process:resourceError];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)stopResource:(NSString *)identifier{
    if (!identifier) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resourceError = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStop identifier:identifier];
            [self process:resourceError];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - error 、 long_task -
- (void)addErrorWithType:(NSString *)type situation:(AppState )situation message:(NSString *)message stack:(NSString *)stack{
    if (!(type && situation && message && stack)) {
        return;
    }
    @try {
        NSDictionary *field = @{ @"error_message":message,
                                 @"error_stack":stack,
        };
        NSDictionary *tags = @{
            @"error_type":type,
            @"error_source":@"logger",
            @"crash_situation":AppStateStringMap[situation]
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
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration{
    if (!stack || !duration) {
        return;
    }
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSDictionary *fields = @{@"duration":duration,
                                     @"long_task_stack":stack
            };
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
    FTMonitorInfoType monitorType = self.rumConfig.monitorInfoType;
    if (monitorType & FTMonitorInfoTypeMemory) {
        errorTag[FT_MONITOR_MEMORY_TOTAL] = [FTMonitorUtils totalMemorySize];
        errorTag[FT_MONITOR_MEM_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils usedMemory]];
    }
    if (monitorType & FTMonitorInfoTypeCpu) {
        errorTag[FT_MONITOR_CPU_USAGE] = [NSNumber numberWithLong:[FTMonitorUtils cpuUsage]];
    }
    if (monitorType & FTMonitorInfoTypeBattery) {
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
        self.sessionHandler = [[FTRUMSessionHandler alloc]initWithModel:model rumConfig:self.rumConfig];
        [self.sessionHandler.assistant process:model];
    }
    
    return YES;
}

-(NSDictionary *)getCurrentSessionInfo{
    return [self.sessionHandler getCurrentSessionInfo];
}
@end
