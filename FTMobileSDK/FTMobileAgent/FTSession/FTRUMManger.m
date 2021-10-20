//
//  FTRUMManger.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTRUMManger.h"
#import "FTBaseInfoHander.h"
#import "FTRUMSessionHandler.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTTaskInterceptionModel.h"
#import "NSURLResponse+FTMonitor.h"
#import "NSURLRequest+FTMonitor.h"
#import "FTDateUtil.h"
#import "FTLog.h"
#import "FTJSONUtil.h"
#import "FTMobileConfig.h"
#import "FTMonitorUtils.h"
#import "FTConstants.h"
#import "FTPresetProperty.h"
#import "FTThreadDispatchManager.h"
@interface FTRUMManger()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
@end
@implementation FTRUMManger

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
#pragma mark - FTRUMSessionErrorDelegate -
- (void)ftErrorWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    NSMutableDictionary *errorTag = [NSMutableDictionary dictionaryWithDictionary:tags];
    [errorTag addEntriesFromDictionary:[self errrorMonitorInfo]];
    
    [FTThreadDispatchManager performBlockDispatchMainSyncSafe:^{
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataError time:[NSDate date]];
        model.tags = errorTag;
        model.fields = field;
        [self process:model];
    }];
    [FTThreadDispatchManager dispatchSyncInRUMThread:^{
        
    }];
    
}
- (void)ftLongTaskWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataLongTask time:[NSDate date]];
            model.tags = tags;
            model.fields = field;
            [self process:model];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - FTRUMSessionActionDelegate -
-(void)ftViewDidAppear:(UIViewController *)viewController{
    @try {
        if(!viewController){
            return;
        }
        NSDate *time = [NSDate date];
        NSString *viewReferrer = viewController.ft_parentVC;
        NSString *viewID = viewController.ft_viewUUID;
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSString *className = NSStringFromClass(viewController.class);
            //viewModel
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewID viewName:className viewReferrer:viewReferrer];
            viewModel.loading_time = viewController.ft_loadDuration;
            FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStart time:time];
            model.baseViewData = viewModel;
            [self process:model];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
    
}
-(void)ftViewDidDisappear:(UIViewController *)viewController{
    @try {
        NSDate *time = [NSDate date];
        NSString *viewReferrer = viewController.ft_parentVC;
        NSString *viewID = viewController.ft_viewUUID;
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSString *className = NSStringFromClass(viewController.class);
            FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewID viewName:className viewReferrer:viewReferrer];
            FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStop time:time];
            model.baseViewData = viewModel;
            [self process:model];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)ftClickView:(UIView *)clickView{
    @try {
        if (!self.rumConfig.enableTraceUserAction) {
            return;
        }
        NSDate *time = [NSDate date];
        NSString *viewTitle = @"";
        if ([clickView isKindOfClass:UIButton.class]) {
            UIButton *btn =(UIButton *)clickView;
            viewTitle = btn.currentTitle.length>0?[NSString stringWithFormat:@"[%@]",btn.currentTitle]:@"";
        }
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSString *className = NSStringFromClass(clickView.class);
            
            NSString *actionName = [NSString stringWithFormat:@"[%@]%@",className,viewTitle];
            
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:actionName actionType:@"click"];
            FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataClick time:time];
            model.baseActionData = actionModel;
            [self process:model];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)ftApplicationDidBecomeActive:(BOOL)isHot duration:(NSNumber *)duration{
    @try {
        if (!self.rumConfig.enableTraceUserAction) {
            return;
        }
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSString *actionName = isHot?@"app_hot_start":@"app_cold_start";
            NSString *actionType = isHot?@"launch_hot":@"launch_cold";
            FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:actionName actionType:actionType];
            FTRUMDataType type = isHot?FTRUMDataLaunchHot:FTRUMDataLaunchCold;
            FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithType:type duration:duration];
            launchModel.baseActionData =actionModel;
            [self process:launchModel];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)ftApplicationWillTerminate{
    @try {
        [FTThreadDispatchManager dispatchSyncInRUMThread:^{
            
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}

#pragma mark - FTRUMSessionSourceDelegate -
- (void)ftResourceCreate:(FTTaskInterceptionModel *)resourceModel{
    @try {
        [FTThreadDispatchManager dispatchInRUMThread:^{
            FTRUMResourceDataModel *resourceStrat = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:resourceModel.identifier];
            
            [self process:resourceStrat];
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
    
}
- (void)ftResourceCompleted:(FTTaskInterceptionModel *)resourceModel{
    @try {
        
        [FTThreadDispatchManager dispatchInRUMThread:^{
            NSURLSessionTask *task = resourceModel.task;
            NSURLSessionTaskTransactionMetrics *taskMes = [resourceModel.metrics.transactionMetrics lastObject];
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSError *error = resourceModel.error?resourceModel.error:response.ft_getResponseError;
            NSMutableDictionary *tags = [NSMutableDictionary new];
            // trace 开启 enableLinkRumData 时 linkTags 有值
            [tags addEntriesFromDictionary:resourceModel.linkTags];
            NSMutableDictionary *fields = [NSMutableDictionary new];
            NSString *url_path_group = [FTBaseInfoHander replaceNumberCharByUrl:task.originalRequest.URL];
            tags[@"resource_url_path_group"] =url_path_group;
            tags[@"resource_url"] = task.originalRequest.URL.absoluteString;
            tags[@"resource_url_host"] = task.originalRequest.URL.host;
            tags[@"resource_url_path"] = task.originalRequest.URL.path;
            tags[@"resource_method"] = task.originalRequest.HTTPMethod;
            tags[@"resource_status"] = error ?[NSNumber numberWithInteger:error.code] : [task.response ft_getResponseStatusCode];
            if(error){
                tags[@"error_source"] = @"network";
                tags[@"error_type"] = [NSString stringWithFormat:@"%@_%ld",error.domain,(long)error.code];
                [tags addEntriesFromDictionary:[self errrorMonitorInfo]];
                
                NSMutableDictionary *field = @{
                    @"error_message":[NSString stringWithFormat:@"[%ld][%@]",(long)error.code,task.originalRequest.URL],
                }.mutableCopy;
                if (resourceModel.data) {
                    NSError *errors;
                    id responseObject = [NSJSONSerialization JSONObjectWithData:resourceModel.data options:NSJSONReadingMutableContainers error:&errors];
                    [field setValue:responseObject forKey:@"error_stack"];
                }
                FTRUMResourceDataModel *resourceError = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceError identifier:resourceModel.identifier];
                resourceError.time = taskMes.requestEndDate;
                resourceError.tags = tags;
                resourceError.fields = field;
                [self process:resourceError];
                
            }else{
                NSDictionary *responseHeader = response.allHeaderFields;
                if ([responseHeader.allKeys containsObject:@"Proxy-Connection"]) {
                    tags[@"response_connection"] =responseHeader[@"Proxy-Connection"];
                }
                tags[@"resource_type"] = response.MIMEType;
                NSString *response_server = [FTBaseInfoHander getIPWithHostName:task.originalRequest.URL.host];
                if (response_server) {
                    tags[@"response_server"] = response_server;
                }
                
                tags[@"response_content_type"] =response.MIMEType;
                if ([responseHeader.allKeys containsObject:@"Content-Encoding"]) {
                    tags[@"response_content_encoding"] = responseHeader[@"Content-Encoding"];
                }
                NSString *group =  [response ft_getResourceStatusGroup];
                if (group) {
                    tags[@"resource_status_group"] = group;
                }
                
                NSNumber *dnsTime = [FTDateUtil nanosecondtimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.domainLookupEndDate];
                NSNumber *tcpTime = [FTDateUtil nanosecondtimeIntervalSinceDate:taskMes.connectStartDate toDate:taskMes.connectEndDate];
                
                NSNumber *tlsTime = taskMes.secureConnectionStartDate!=nil ? [FTDateUtil nanosecondtimeIntervalSinceDate:taskMes.secureConnectionStartDate toDate:taskMes.connectEndDate]:@0;
                NSNumber *ttfbTime = [FTDateUtil nanosecondtimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseStartDate];
                NSNumber *transTime =[FTDateUtil nanosecondtimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseEndDate];
                NSNumber *durationTime = [FTDateUtil nanosecondtimeIntervalSinceDate:taskMes.fetchStartDate toDate:taskMes.requestEndDate];
                NSNumber *resourceFirstByteTime = [FTDateUtil nanosecondtimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.responseStartDate];
                fields[@"resource_first_byte"] = resourceFirstByteTime;
                fields[@"resource_size"] =[NSNumber numberWithLongLong:task.countOfBytesReceived+[response ft_getResponseHeaderDataSize]];
                fields[@"duration"] =durationTime;
                fields[@"resource_dns"] = dnsTime;
                fields[@"resource_tcp"] = tcpTime;
                fields[@"resource_ssl"] = tlsTime;
                fields[@"resource_ttfb"] = ttfbTime;
                fields[@"resource_trans"] = transTime;
                if (response) {
                    fields[@"response_header"] =[FTBaseInfoHander convertToStringData:response.allHeaderFields];
                    fields[@"request_header"] = [FTBaseInfoHander convertToStringData:[task.currentRequest ft_getRequestHeaders]];
                }
                tags[@"resource_url"] = task.originalRequest.URL.absoluteString;
                tags[@"resource_url_query"] =[task.originalRequest.URL query];
                tags[@"resource_url_path_group"] = url_path_group;
                
                FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceSuccess identifier:resourceModel.identifier];
                resourceSuccess.tags = tags;
                resourceSuccess.fields = fields;
                [self process:resourceSuccess];
            }
        }];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (NSDictionary *)errrorMonitorInfo{
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
#pragma mark - FTRUMWebViewJSBridgeDataDelegate -

- (void)ftWebviewDataWithMeasurement:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    @try {
        FTRUMWebViewData *webModel = [[FTRUMWebViewData alloc]initWithMeasurement:measurement tm:tm];
        webModel.tags = tags;
        webModel.fields = fields;
        [self process:webModel];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
#pragma mark - FTRUMSessionProtocol -
-(BOOL)process:(FTRUMDataModel *)model{
    @try {
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
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
    return YES;
}

-(NSDictionary *)getCurrentSessionInfo{
    @try {
        return [self.sessionHandler getCurrentSessionInfo];
        
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
        
    }
    return @{};
}
@end
