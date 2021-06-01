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
@interface FTRUMManger()<FTRUMSessionProtocol>
@property (nonatomic, strong) FTRUMSessionHandler *sessionHandler;
@property (nonatomic, weak) UIViewController *currentViewController;
@property (nonatomic, strong) dispatch_queue_t concurrentQueue;
@property (nonatomic, strong) FTMobileConfig *config;
@end
@implementation FTRUMManger

-(instancetype)initWithConfig:(FTMobileConfig *)config{
    self = [super init];
    if (self) {
        self.config = config;
        self.assistant = self;
        self.concurrentQueue= dispatch_queue_create([@"io.concurrentQueue.rum" UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark - FTRUMSessionErrorDelegate -
- (void)ftErrorWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataError time:[NSDate date]];
    model.tags = tags;
    model.fields = field;
    [self process:model];
}
- (void)ftLongTaskWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataLongTask time:[NSDate date]];
    model.tags = tags;
    model.fields = field;
    [self process:model];
}
#pragma mark - FTRUMSessionActionDelegate -
-(void)ftViewDidAppear:(UIViewController *)viewController{
    NSDate *time = [NSDate date];
    self.currentViewController = viewController;
    NSString *className = NSStringFromClass(viewController.class);
    //viewModel
    FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[NSUUID UUID].UUIDString viewName:className viewReferrer:viewController.ft_parentVC];
    viewModel.loading_time = viewController.ft_loadDuration;
    FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStart time:time];
    model.baseViewData = viewModel;
    [self process:model];
    
}
-(void)ftViewDidDisappear:(UIViewController *)viewController{
    NSDate *time = [NSDate date];
    FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStop time:time];
    [self process:model];
    
}
- (void)ftClickView:(UIView *)clickView{
    if (!self.config.enableTraceUserAction) {
        return;
    }
    NSDate *time = [NSDate date];
    NSString *className = NSStringFromClass(clickView.class);
    NSString *viewTitle = @"";
    if ([clickView isKindOfClass:UIButton.class]) {
        UIButton *btn =(UIButton *)clickView;
        viewTitle = btn.currentTitle.length>0?[NSString stringWithFormat:@"[%@]",btn.currentTitle]:@"";
    }
    NSString *actionName = [NSString stringWithFormat:@"[%@]%@click",className,viewTitle];
    
    FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:actionName actionType:@"click"];
    FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataClick time:time];
    model.baseActionData = actionModel;
    [self process:model];
}
- (void)ftApplicationDidBecomeActive:(BOOL)isHot{
    NSDate *time = [NSDate date];
    //热启动时 如果有viewController 开启view
    if (isHot&&_currentViewController) {
        NSString *className = NSStringFromClass(_currentViewController.class);
        NSString *vcTitle = _currentViewController.title.length>0?[NSString stringWithFormat:@"[%@]",_currentViewController.title]:@"";
        NSString *startActionType = [NSString stringWithFormat:@"[%@]%@start",className,vcTitle];
        FTRUMActionModel *startActionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:@"view" actionType:startActionType];
        FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[NSUUID UUID].UUIDString viewName:className viewReferrer:_currentViewController.ft_parentVC];
        FTRUMDataModel *startModel = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStart time:time];
        startModel.baseActionData = startActionModel;
        startModel.baseViewData = viewModel;
        [self process:startModel];
    }
    if (!self.config.enableTraceUserAction) {
        return;
    }
    NSString *actionName = isHot?@"app_hot_start":@"app_cold_start";
    NSString *actionType = isHot?@"launch_hot":@"launch_cold";
    FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:actionName actionType:actionType];
    FTRUMDataType type = isHot?FTRUMDataLaunchHot:FTRUMDataLaunchCold;
    FTRUMDataModel *launchModel = [[FTRUMDataModel alloc]initWithType:type time:time];
    launchModel.baseActionData =actionModel;
    [self process:launchModel];
}
- (void)ftApplicationWillResignActive{
    NSDate *time = [NSDate date];
    if (_currentViewController) {
        NSString *className = NSStringFromClass(_currentViewController.class);
        NSString *vcTitle = _currentViewController.title.length>0?[NSString stringWithFormat:@"[%@]",_currentViewController.title]:@"";
        NSString *actionType = [NSString stringWithFormat:@"[%@]%@stop",className,vcTitle];
        FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:@"view" actionType:actionType];
        FTRUMDataModel *model = [[FTRUMDataModel alloc]initWithType:FTRUMDataViewStop time:time];
        model.baseActionData = actionModel;
        [self process:model];
    }
    
}

#pragma mark - FTRUMSessionSourceDelegate -
- (void)ftResourceCreate:(FTTaskInterceptionModel *)resourceModel{
    FTRUMResourceDataModel *resourceStrat = [[FTRUMResourceDataModel alloc]initWithType:FTRUMDataResourceStart identifier:resourceModel.identifier];
    
    [self process:resourceStrat];
}
- (void)ftResourceCompleted:(FTTaskInterceptionModel *)resourceModel{
    NSURLSessionTask *task = resourceModel.task;
    NSURLSessionTaskTransactionMetrics *taskMes = [resourceModel.metrics.transactionMetrics lastObject];
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    NSError *error = resourceModel.error?resourceModel.error:response.ft_getResponseError;
    NSMutableDictionary *tags = [NSMutableDictionary new];
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
        NSDictionary *field = @{@"error_message":error.localizedDescription,
                                @"error_stack":error,
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
        fields[@"resource_size"] =[NSNumber numberWithLongLong:task.countOfBytesReceived];
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
        self.sessionHandler = [[FTRUMSessionHandler alloc]initWithModel:model];
        [self.sessionHandler.assistant process:model];
    }
    
    return YES;
}
@end
