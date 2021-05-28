//
//  FTSessionManger.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTSessionManger.h"
#import "FTBaseInfoHander.h"
#import "FTRUMSessionScope.h"
#import "FTRUMScope.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTTaskInterceptionModel.h"
#import "NSURLResponse+FTMonitor.h"
#import "NSURLRequest+FTMonitor.h"
#import "NSDate+FTAdd.h"
@interface FTSessionManger()<FTRUMScopeProtocol>
@property (nonatomic, strong) FTRUMSessionScope *sessionScope;
@property (nonatomic, weak) UIViewController *currentViewController;

@end
@implementation FTSessionManger

-(instancetype)init{
    self = [super init];
    if (self) {
        self.assistant = self;
    }
    return self;
}

#pragma mark - FTRUMSessionErrorDelegate -
- (void)notify_errorWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    FTRUMCommand *model = [[FTRUMCommand alloc]initWithType:FTRUMDataViewError time:[NSDate date]];
    model.tags = tags;
    model.fields = field;
    [self process:model];
}
- (void)notify_longTaskWithtags:(NSDictionary *)tags field:(NSDictionary *)field{
    FTRUMCommand *model = [[FTRUMCommand alloc]initWithType:FTRUMDataViewLongTask time:[NSDate date]];
    model.tags = tags;
    model.fields = field;
    [self process:model];
}
#pragma mark - FTRUMSessionActionDelegate -
-(void)notify_viewDidAppear:(UIViewController *)viewController{
    NSDate *time = [NSDate date];
    self.currentViewController = viewController;
    NSString *className = NSStringFromClass(viewController.class);
    NSString *vcTitle = viewController.title.length>0?[NSString stringWithFormat:@"[%@]",_currentViewController.title]:@"";
    NSString *actionType = [NSString stringWithFormat:@"[%@]%@start",className,vcTitle];
    FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:@"view" actionType:actionType];

    NSDictionary *filed = @{@"duration":viewController.ft_loadDuration};
    //viewModel
    FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[NSUUID UUID].UUIDString viewName:className viewReferrer:viewController.ft_parentVC];
    FTRUMCommand *model = [[FTRUMCommand alloc]initWithType:FTRUMDataViewStart time:time];
    model.baseActionData = actionModel;
    model.baseViewData = viewModel;
    model.fields = filed;
    [self process:model];
   
}
-(void)notify_viewDidDisappear:(UIViewController *)viewController{
    NSDate *time = [NSDate date];
    NSString *className = NSStringFromClass(viewController.class);
    NSString *vcTitle = viewController.title.length>0?[NSString stringWithFormat:@"[%@]",_currentViewController.title]:@"";
    NSString *actionType = [NSString stringWithFormat:@"[%@]%@stop",className,vcTitle];

    FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:@"view" actionType:actionType];
    FTRUMCommand *model = [[FTRUMCommand alloc]initWithType:FTRUMDataViewStop time:time];
    model.baseActionData = actionModel;
    [self process:model];
    
}
- (void)notify_clickView:(UIView *)clickView{
    NSDate *time = [NSDate date];
    NSString *className = NSStringFromClass(clickView.class);
    NSString *viewTitle = @"";
    if ([clickView isKindOfClass:UIButton.class]) {
        UIButton *btn =(UIButton *)clickView;
        viewTitle = btn.currentTitle.length>0?[NSString stringWithFormat:@"[%@]",btn.currentTitle]:@"";
    }
    NSString *actionType = [NSString stringWithFormat:@"[%@]%@click",className,viewTitle];
    
    FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:@"click" actionType:actionType];
    FTRUMCommand *model = [[FTRUMCommand alloc]initWithType:FTRUMDataClick time:time];
    model.baseActionData = actionModel;
    [self process:model];
}
- (void)notify_applicationDidBecomeActive:(BOOL)isHot{
    NSDate *time = [NSDate date];
   //热启动时 如果有viewController 开启view
    if (isHot&&_currentViewController) {
        NSString *className = NSStringFromClass(_currentViewController.class);
        NSString *vcTitle = _currentViewController.title.length>0?[NSString stringWithFormat:@"[%@]",_currentViewController.title]:@"";
        NSString *startActionType = [NSString stringWithFormat:@"[%@]%@start",className,vcTitle];
        FTRUMActionModel *startActionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:@"view" actionType:startActionType];
        FTRUMViewModel *viewModel = [[FTRUMViewModel alloc]initWithViewID:[NSUUID UUID].UUIDString viewName:className viewReferrer:_currentViewController.ft_parentVC];
        FTRUMCommand *startModel = [[FTRUMCommand alloc]initWithType:FTRUMDataViewStart time:time];
        startModel.baseActionData = startActionModel;
        startModel.baseViewData = viewModel;
        [self process:startModel];
    }
    NSString *actionType = isHot?@"app_hot_start":@"app_cold_start";
    NSString *actionName = isHot?@"launch_hot":@"launch_cold";
    FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:actionName actionType:actionType];
    FTRUMCommandType type = isHot?FTRUMDataLaunchHot:FTRUMDataLaunchCold;
    FTRUMCommand *launchModel = [[FTRUMCommand alloc]initWithType:type time:time];
    launchModel.baseActionData =actionModel;
    [self process:launchModel];
}
- (void)notify_applicationWillResignActive{
    NSDate *time = [NSDate date];
    if (_currentViewController) {
        NSString *className = NSStringFromClass(_currentViewController.class);
        NSString *vcTitle = _currentViewController.title.length>0?[NSString stringWithFormat:@"[%@]",_currentViewController.title]:@"";
        NSString *actionType = [NSString stringWithFormat:@"[%@]%@stop",className,vcTitle];
        FTRUMActionModel *actionModel = [[FTRUMActionModel alloc]initWithActionID:[NSUUID UUID].UUIDString actionName:@"view" actionType:actionType];
        FTRUMCommand *model = [[FTRUMCommand alloc]initWithType:FTRUMDataViewStop time:time];
        model.baseActionData = actionModel;
        [self process:model];
    }
   
}

#pragma mark - FTRUMSessionSourceDelegate -
- (void)notify_resourceCreate:(FTTaskInterceptionModel *)resourceModel{
    FTRUMResourceCommand *resourceStrat = [[FTRUMResourceCommand alloc]initWithType:FTRUMDataViewResourceStart identifier:resourceModel.identifier];
    
    [self process:resourceStrat];
}
- (void)notify_resourceCompleted:(FTTaskInterceptionModel *)resourceModel{
    NSURLSessionTask *task = resourceModel.task;
    NSError *error = resourceModel.error;
    NSURLSessionTaskTransactionMetrics *taskMes = [resourceModel.metrics.transactionMetrics lastObject];
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;

    NSMutableDictionary *tags = [NSMutableDictionary new];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    NSString *url_path_group = [FTBaseInfoHander urlPathGroup:task.originalRequest.URL];
    tags[@"resource_url_path_group"] =url_path_group;
    tags[@"resource_url"] = task.originalRequest.URL.absoluteString;
    tags[@"resource_url_host"] = task.originalRequest.URL.host;
    tags[@"resource_url_path"] = task.originalRequest.URL.path;
    tags[@"resource_method"] = task.originalRequest.HTTPMethod;
    tags[@"resource_status"] = error ?[NSNumber numberWithInteger:error.code] : [task.response ft_getResponseStatusCode];
    if(error || [[task.response ft_getResponseStatusCode] integerValue] >=400){
        tags[@"error_starttime"] = @([taskMes.requestEndDate ft_dateTimestamp]);
        tags[@"error_message"] = error?[NSString stringWithFormat:@"%@-%ld",error.domain,(long)error.code]:@(response.statusCode);
        tags[@"error_stack"] = @"error";
        tags[@"error_source"] = @"network";
        tags[@"error_type"] = @"network";
        FTRUMResourceCommand *resourceError = [[FTRUMResourceCommand alloc]initWithType:FTRUMDataViewResourceError identifier:resourceModel.identifier];
        resourceError.tags = tags;
        [self process:resourceError];

    }else{
    NSDictionary *responseHeader = response.allHeaderFields;
    NSString *url_path_group =task.originalRequest.URL.relativePath ;
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
        
        FTRUMResourceCommand *resourceSuccess = [[FTRUMResourceCommand alloc]initWithType:FTRUMDataViewResourceSuccess identifier:resourceModel.identifier];
        resourceSuccess.tags = tags;
        resourceSuccess.fields = fields;
        [self process:resourceSuccess];
    }

}
#pragma mark - FTRUMScopeProtocol -
-(BOOL)process:(FTRUMCommand *)commond{
    FTRUMSessionScope *current  = self.sessionScope;
    if (current) {
        if ([self manage:self.sessionScope byPropagatingCommand:commond] == nil) {
          //刷新
            [self.sessionScope refreshWithDate:commond.time];
            [self.sessionScope.assistant process:commond];
        }
    }else{
        //初始化
        self.sessionScope = [[FTRUMSessionScope alloc]initWithModel:commond];
        [self.sessionScope.assistant process:commond];
    }
    
    return YES;
}
@end
