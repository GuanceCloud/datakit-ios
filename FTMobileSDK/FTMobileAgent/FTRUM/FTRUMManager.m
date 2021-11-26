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
#import "FTNetworkTrace.h"
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
    if (!self.rumConfig.enableTraceUserAction) {
        ZYDebug(@"enableTraceUserAction:NO");
        return;
    }
    if (!actionName) {
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
        ZYDebug(@"enableTraceUserAction:NO");
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
- (void)addResource:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(NSString *)spanID traceID:(NSString *)traceID{
    if (!identifier) {
        return;
    }
    @try {
        NSDate *time = [NSDate date];
        NSMutableDictionary *tags = [NSMutableDictionary new];
        NSMutableDictionary *fields = [NSMutableDictionary new];
        NSString *url_path_group = [FTBaseInfoHandler replaceNumberCharByUrl:content.url];
        [tags setValue:content.url.absoluteString forKey:@"resource_url"];
        [tags setValue:content.url.host forKey:@"resource_url_host"];
        [tags setValue:content.url.path forKey:@"resource_url_path"];
        [tags setValue:url_path_group forKey:@"resource_url_path_group"];
        [tags setValue:@(content.httpStatusCode) forKey:@"resource_status"];
        [tags setValue:[self getResourceStatusGroup:content.httpStatusCode] forKey:@"resource_status_group"];
        [fields setValue:@0 forKey:@"resource_size"];
        if (content.responseBody) {
            NSData *data = [content.responseBody dataUsingEncoding:NSUTF8StringEncoding];
            [fields setValue:@(data.length) forKey:@"resource_size"];
        }
        if ([FTNetworkTrace sharedInstance].enableLinkRumData) {
            [tags setValue:spanID forKey:@"span_id"];
            [tags setValue:traceID forKey:@"trace_id"];
        }
        if (content.error || content.httpStatusCode>=400) {
            NSInteger code = content.httpStatusCode == -1?:content.error.code;
            NSString *run = AppStateStringMap[[FTMonitorManager sharedInstance].running];
            [fields setValue:[NSString stringWithFormat:@"[%ld][%@]",(long)code,content.url.absoluteString] forKey:@"error_message"];
            [tags setValue:run forKey:@"error_situation"];
            [tags setValue:content.httpMethod forKey:@"resource_method"];
            [tags setValue:@(content.httpStatusCode) forKey:@"resource_status"];
            [tags setValue:@"network" forKey:@"error_source"];
            [tags setValue:@"network" forKey:@"error_type"];
            if (content.responseBody.length>0) {
                [fields setValue:content.responseBody forKey:@"error_stack"];
            }
            [FTThreadDispatchManager dispatchInRUMThread:^{
                FTRUMResourceDataModel *resourceError = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceError identifier:identifier];
                NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:[self errorMonitorInfo]];
                [newTags addEntriesFromDictionary:tags];
                resourceError.time = time;
                resourceError.tags = newTags;
                resourceError.fields = fields;
                [self process:resourceError];
            }];
        }else{
            
            [tags setValue:[content.url query] forKey:@"resource_url_query"];
            [tags setValue:content.httpMethod forKey:@"resource_method"];
            [tags setValue:content.responseHeader[@"Connection"] forKey:@"response_connection"];
            [tags setValue:content.responseHeader[@"Content-Type"] forKey:@"response_content_type"];
            [tags setValue:content.responseHeader[@"Content-Encoding"] forKey:@"response_content_encoding"];
            [tags setValue:content.responseHeader[@"Content-Type"] forKey:@"resource_type"];
            [fields setValue:[FTBaseInfoHandler convertToStringData:content.requestHeader] forKey:@"request_header"];
            [fields setValue:[FTBaseInfoHandler convertToStringData:content.responseHeader] forKey:@"response_header"];
            
            [FTThreadDispatchManager dispatchInRUMThread:^{
                FTRUMResourceDataModel *resourceSuccess = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceSuccess identifier:identifier];
                resourceSuccess.metrics = metrics;
                resourceSuccess.time = time;
                resourceSuccess.tags = tags;
                resourceSuccess.fields = fields;
                [self process:resourceSuccess];
            }];
            
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
