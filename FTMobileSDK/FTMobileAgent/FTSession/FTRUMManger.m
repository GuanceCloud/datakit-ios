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
#import "NSDate+FTAdd.h"
#import "FTLog.h"
#import "FTJSONUtil.h"
#import "FTMobileConfig.h"
#import "FTPingThread.h"
@interface FTRUMManger()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) FTPingThread *pingThread;

@end
@implementation FTRUMManger

-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig{
    self = [super init];
    if (self) {
        self.rumConfig = rumConfig;
        self.assistant = self;
        self.serialQueue= dispatch_queue_create([@"io.serialQueue.rum" UTF8String], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
-(void)setRumConfig:(FTRumConfig *)rumConfig{
    _rumConfig = rumConfig;
}
#pragma mark - FTRUMSessionErrorDelegate -
- (void)ftErrorWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    dispatch_sync(self.serialQueue, ^{
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataError time:[NSDate date]];
        model.tags = tags;
        model.fields = field;
        [self process:model];
    });
}
- (void)ftLongTaskWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    dispatch_async(self.serialQueue, ^{
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataLongTask time:[NSDate date]];
        model.tags = tags;
        model.fields = field;
        [self process:model];
    });
    
}
#pragma mark - FTRUMSessionActionDelegate -
-(void)ftViewDidAppear:(UIViewController *)viewController{
    NSDate *time = [NSDate date];
    NSString *viewReferrer = viewController.ft_parentVC;
    NSString *viewID = viewController.ft_viewUUID;
    dispatch_async(self.serialQueue, ^{
        NSString *className = NSStringFromClass(viewController.class);
        //viewModel
        FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewID viewName:className viewReferrer:viewReferrer];
        viewModel.loading_time = viewController.ft_loadDuration;
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStart time:time];
        model.baseViewData = viewModel;
        [self process:model];
    });
}
-(void)ftViewDidDisappear:(UIViewController *)viewController{
    NSDate *time = [NSDate date];
    NSString *viewReferrer = viewController.ft_parentVC;
    NSString *viewID = viewController.ft_viewUUID;
    dispatch_async(self.serialQueue, ^{
        NSString *className = NSStringFromClass(viewController.class);
        FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:viewID viewName:className viewReferrer:viewReferrer];
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStop time:time];
        model.baseViewData = viewModel;
        [self process:model];
    });
    
}
- (void)ftClickView:(UIView *)clickView{
    if (!self.rumConfig.enableTraceUserAction) {
        return;
    }
    NSDate *time = [NSDate date];
    NSString *viewTitle = @"";
    if ([clickView isKindOfClass:UIButton.class]) {
        UIButton *btn =(UIButton *)clickView;
        viewTitle = btn.currentTitle.length>0?[NSString stringWithFormat:@"[%@]",btn.currentTitle]:@"";
    }
    dispatch_async(self.serialQueue, ^{
        NSString *className = NSStringFromClass(clickView.class);
        
        NSString *actionName = [NSString stringWithFormat:@"[%@]%@click",className,viewTitle];
        
        FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:actionName actionType:@"click"];
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataClick time:time];
        model.baseActionData = actionModel;
        [self process:model];
    });
}
- (void)ftApplicationDidBecomeActive:(BOOL)isHot duration:(NSNumber *)duration{
    if (!self.rumConfig.enableTraceUserAction) {
        return;
    }
    dispatch_async(self.serialQueue, ^{
        NSString *actionName = isHot?@"app_hot_start":@"app_cold_start";
        NSString *actionType = isHot?@"launch_hot":@"launch_cold";
        FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:actionName actionType:actionType];
        FTRUMDataType type = isHot?FTRUMDataLaunchHot:FTRUMDataLaunchCold;
        FTRUMLaunchDataModel *launchModel = [[FTRUMLaunchDataModel alloc]initWithType:type duration:duration];
        launchModel.baseActionData =actionModel;
        [self process:launchModel];
    });
}
- (void)ftApplicationWillTerminate{
    dispatch_sync(self.serialQueue, ^{
    });
}

#pragma mark - FTRUMSessionSourceDelegate -
- (void)ftResourceCreate:(FTTaskInterceptionModel *)resourceModel{
    dispatch_async(self.serialQueue, ^{
        FTRUMResourceDataModel *resourceStrat = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:resourceModel.identifier];
        
        [self process:resourceStrat];
    });
}
- (void)ftResourceCompleted:(FTTaskInterceptionModel *)resourceModel{
    dispatch_async(self.serialQueue, ^{
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
            NSDictionary *field = @{
                @"error_message":error.localizedDescription,
                @"error_stack":@{
                        @"domain":error.domain,
                        @"code":@(error.code),
                        @"userInfo":error.userInfo
                },
            };
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
            NSNumber *dnsTime = [taskMes.domainLookupEndDate ft_nanotimeIntervalSinceDate:taskMes.domainLookupStartDate];
            NSNumber *tcpTime = [taskMes.connectEndDate ft_nanotimeIntervalSinceDate:taskMes.connectStartDate];
            NSNumber *tlsTime = taskMes.secureConnectionStartDate!=nil ? [taskMes.connectEndDate ft_nanotimeIntervalSinceDate:taskMes.secureConnectionStartDate]:@0;
            NSNumber *ttfbTime = [taskMes.responseStartDate ft_nanotimeIntervalSinceDate:taskMes.requestStartDate];
            NSNumber *transTime =[taskMes.responseEndDate ft_nanotimeIntervalSinceDate:taskMes.requestStartDate];
            NSNumber *durationTime = [taskMes.requestEndDate ft_nanotimeIntervalSinceDate:taskMes.fetchStartDate];
            NSNumber *resourceFirstByteTime = [taskMes.responseStartDate ft_nanotimeIntervalSinceDate:taskMes.domainLookupStartDate];
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
    });
    
}
#pragma mark - FTRUMWebViewJSBridgeDataDelegate -

- (void)ftWebviewDataWithMeasurement:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm{
    FTRUMWebViewData *webModel = [[FTRUMWebViewData alloc]initWithMeasurement:measurement tm:tm];
    webModel.tags = tags;
    webModel.fields = fields;
    [self process:webModel];
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
