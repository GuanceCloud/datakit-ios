//
//  FTTraceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTTraceHandler.h"
#import "FTBaseInfoHandler.h"
#import "FTMonitorManager.h"
#import "FTMobileAgent+Private.h"
#import "FTDateUtil.h"
#import "FTNetworkTrace.h"
#import "NSURLResponse+FTMonitor.h"
#import "NSURLRequest+FTMonitor.h"
#import "FTJSONUtil.h"
#import "FTRUMManager.h"
@interface FTTraceHandler ()
@property (nonatomic, assign) BOOL isSampling;
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, copy) NSString *span_id;
@property (nonatomic, copy) NSString *trace_id;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;

@end
@implementation FTTraceHandler
-(instancetype)initWithUrl:(NSURL *)url{
    self = [super init];
    if (self) {
        self.url = url;
        self.startTime = [NSDate date];
        self.identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(instancetype)init{
    return [self initWithUrl:nil];
}
- (NSDictionary *)getTraceHeader{
    if (!self.url) {
        return nil;
    }
    self.requestHeader = [[FTNetworkTrace sharedInstance] networkTrackHeaderWithUrl:self.url];
    return self.requestHeader;
}
-(void)tracingContent:(NSString *)content tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    if(!content){
        return;
    }
    if (self.isSampling) {
        NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:tags];
        [newTags addEntriesFromDictionary:[self getTraceSpanID]];
        [newTags setValue:[FTNetworkTrace sharedInstance].service forKey:FT_KEY_SERVICE];
        [[FTMobileAgent sharedInstance] tracing:content tags:newTags field:fields tm:[FTDateUtil dateTimeNanosecond:self.startTime]];
    }
}
#pragma mark - private -
-(void)setRequestHeader:(NSDictionary *)requestHeader{
    _requestHeader = requestHeader;
    [self resolveRequestHeader];
}
- (void)resolveRequestHeader{
    __weak typeof(self) weakSelf = self;
    [[FTNetworkTrace sharedInstance] getTraceingDatasWithRequestHeaderFields:self.requestHeader handler:^(NSString * _Nonnull traceId, NSString * _Nonnull spanID, BOOL sampled) {
        weakSelf.trace_id = traceId;
        weakSelf.span_id = spanID;
        weakSelf.isSampling = sampled;
    }];
}
- (NSDictionary *)getTraceSpanID{
    if (self.span_id&&self.trace_id) {
        return @{@"span_id":self.span_id,
                 @"trace_id":self.trace_id
        };
    }else{
        return nil;
    }
}
-(NSDate *)endTime{
    if (!_endTime) {
        _endTime = [NSDate date];
    }
    return _endTime;
}
- (void)resourceCompleted{

    NSURLSessionTaskTransactionMetrics *taskMes = [self.metrics.transactionMetrics lastObject];

    [self traceRequest:self.task.currentRequest response:(NSHTTPURLResponse *)self.task.response startDate:taskMes.requestStartDate taskDuration:[NSNumber numberWithInt:[self.metrics.taskInterval duration]*1000000] error:self.error];
    
    [self rumDataWrite];
}
- (void)traceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error{
    if (self.isSampling) {
        FTStatus status = FTStatusOk;
        NSDictionary *responseDict = @{};
        if (error) {
            status = FTStatusError;
            NSString *errorDescription=[[error.userInfo allKeys] containsObject:@"NSLocalizedDescription"]?error.userInfo[@"NSLocalizedDescription"]:@"";
            NSNumber *errorCode = [NSNumber numberWithInteger:error.code];
            responseDict = @{FT_NETWORK_HEADERS:@{},
                             FT_NETWORK_BODY:@{},
                             FT_NETWORK_ERROR:@{@"errorCode":[NSNumber numberWithInteger:error.code],
                                                @"errorDomain":error.domain,
                                                @"errorDescription":errorDescription,
                             },
                             FT_NETWORK_CODE:errorCode,
            };
        }else{
            if( [[response ft_getResponseStatusCode] integerValue] >=400){
                status = FTStatusError;
            }
            responseDict = response?[response ft_getResponseDict]:responseDict;
        }
        NSString *statusStr = [FTBaseInfoHandler statusStrWithStatus:status];
        NSMutableDictionary *requestDict = [request ft_getRequestContentDict].mutableCopy;
        NSDictionary *responseDic = responseDict?responseDict:@{};
        NSDictionary *content = @{
            FT_NETWORK_RESPONSE_CONTENT:responseDic,
            FT_NETWORK_REQUEST_CONTENT:requestDict
        };
        NSString *operation = [request ft_getOperationName];
        NSMutableDictionary *tags = @{FT_KEY_OPERATION:operation,
                                      FT_TRACING_STATUS:statusStr,
                                      FT_KEY_SPANTYPE:FT_SPANTYPE_ENTRY,
                                      FT_TYPE_RESOURCE:operation,
                                      FT_TYPE:@"custom",
        }.mutableCopy;
        NSDictionary *field = @{FT_KEY_DURATION:duration};
        [tags setValue:[FTNetworkTrace sharedInstance].service forKey:FT_KEY_SERVICE];
        self.startTime = start;
        [self tracingContent:[FTJSONUtil convertToJsonData:content] tags:tags fields:field];
    }
}

#pragma mark - RUM 相关操作 -
//rum resourceStart
-(void)rumResourceStart{

    [[FTMonitorManager sharedInstance].rumManger resourceStart:self.identifier];
}
-(void)rumResourceCompletedWithTags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:tags];
    // trace 开启 enableLinkRumData 时 添加 span_id、trace_id tag
    if (self.isSampling && [FTNetworkTrace sharedInstance].enableLinkRumData) {
        [newTags addEntriesFromDictionary:[self getTraceSpanID]];
    }
    [[FTMonitorManager sharedInstance].rumManger resourceCompleted:self.identifier tags:newTags fields:fields time:self.endTime];
}
-(void)rumResourceCompletedErrorWithTags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:tags];
    // trace 开启 enableLinkRumData 时 添加 span_id、trace_id tag
    if (self.isSampling && [FTNetworkTrace sharedInstance].enableLinkRumData) {
        [newTags addEntriesFromDictionary:[self getTraceSpanID]];
    }
    [[FTMonitorManager sharedInstance].rumManger resourceError:self.identifier tags:newTags fields:fields time:self.endTime];
}
- (void)rumDataWrite{
    //  RUM 未开启时 rumManger == nil
    if (![FTMonitorManager sharedInstance].rumManger) {
        return;
    }
    NSURLSessionTaskTransactionMetrics *taskMes = [self.metrics.transactionMetrics lastObject];
    self.endTime = taskMes.responseEndDate;
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)self.task.response;
    NSError *error = self.error?:response.ft_getResponseError;
    NSMutableDictionary *tags = [NSMutableDictionary new];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    NSString *url_path_group = [FTBaseInfoHandler replaceNumberCharByUrl:self.task.originalRequest.URL];
    tags[@"resource_url_path_group"] =url_path_group;
    tags[@"resource_url"] = self.task.originalRequest.URL.absoluteString;
    tags[@"resource_url_host"] = self.task.originalRequest.URL.host;
    tags[@"resource_url_path"] = self.task.originalRequest.URL.path;
    tags[@"resource_method"] = self.task.originalRequest.HTTPMethod;
    tags[@"resource_status"] = error ?[NSNumber numberWithInteger:error.code] : [response ft_getResponseStatusCode];
    if(error){
        tags[@"error_source"] = @"network";
        tags[@"error_type"] = [NSString stringWithFormat:@"%@_%ld",error.domain,(long)error.code];
        
        NSMutableDictionary *field = @{
            @"error_message":[NSString stringWithFormat:@"[%ld][%@]",(long)error.code,self.task.originalRequest.URL],
        }.mutableCopy;
        if (self.data) {
            NSError *errors;
            id responseObject = [NSJSONSerialization JSONObjectWithData:self.data options:NSJSONReadingMutableContainers error:&errors];
            [field setValue:responseObject forKey:@"error_stack"];
        }
        [self rumResourceCompletedErrorWithTags:tags fields:field];
    }else{
        NSDictionary *responseHeader = response.allHeaderFields;
        if ([responseHeader.allKeys containsObject:@"Proxy-Connection"]) {
            tags[@"response_connection"] =responseHeader[@"Proxy-Connection"];
        }
        tags[@"resource_type"] = response.MIMEType;
        NSString *response_server = [FTBaseInfoHandler getIPWithHostName:self.task.originalRequest.URL.host];
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
        
        NSNumber *dnsTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.domainLookupEndDate];
        NSNumber *tcpTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.connectStartDate toDate:taskMes.connectEndDate];
        
        NSNumber *tlsTime = taskMes.secureConnectionStartDate!=nil ? [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.secureConnectionStartDate toDate:taskMes.connectEndDate]:@0;
        NSNumber *ttfbTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseStartDate];
        NSNumber *transTime =[FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseEndDate];
        NSNumber *durationTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.fetchStartDate toDate:taskMes.requestEndDate];
        NSNumber *resourceFirstByteTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.responseStartDate];
        fields[@"resource_first_byte"] = resourceFirstByteTime;
        fields[@"resource_size"] =[NSNumber numberWithLongLong:self.task.countOfBytesReceived+[response ft_getResponseHeaderDataSize]];
        fields[@"duration"] =durationTime;
        fields[@"resource_dns"] = dnsTime;
        fields[@"resource_tcp"] = tcpTime;
        fields[@"resource_ssl"] = tlsTime;
        fields[@"resource_ttfb"] = ttfbTime;
        fields[@"resource_trans"] = transTime;
        if (response) {
            fields[@"response_header"] =[FTBaseInfoHandler convertToStringData:response.allHeaderFields];
            fields[@"request_header"] = [FTBaseInfoHandler convertToStringData:[_task.currentRequest ft_getRequestHeaders]];
        }
        tags[@"resource_url"] = self.task.originalRequest.URL.absoluteString;
        tags[@"resource_url_query"] =[_task.originalRequest.URL query];
        tags[@"resource_url_path_group"] = url_path_group;
        [self rumResourceCompletedWithTags:tags fields:fields];
    }

}
@end
