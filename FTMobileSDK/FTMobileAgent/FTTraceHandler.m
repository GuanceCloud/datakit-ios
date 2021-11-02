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
#import "FTResourceContentModel.h"
@interface FTTraceHandler ()
@property (nonatomic, strong) NSDictionary *requestHeader;
@property (nonatomic, strong,nullable) NSError *error;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) BOOL isSampling;
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, copy) NSString *span_id;
@property (nonatomic, copy) NSString *trace_id;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@end
@implementation FTTraceHandler
-(instancetype)initWithUrl:(NSURL *)url{
    return [self initWithUrl:url identifier:[NSUUID UUID].UUIDString];
}
-(instancetype)initWithUrl:(NSURL *)url identifier:(NSString *)identifier{
    self = [super init];
    if (self) {
        self.url = url;
        self.startTime = [NSDate date];
        self.identifier = identifier;
    }
    return self;
}
- (NSDictionary *)getTraceHeader{
    if (!self.url) {
        return nil;
    }
    self.requestHeader = [[FTNetworkTrace sharedInstance] networkTrackHeaderWithUrl:self.url];
    return self.requestHeader;
}
-(void)tracingContent:(NSString *)content HTTPMethod:(NSString *)HTTPMethod isError:(BOOL)isError{
    if(!content){
        return;
    }
    NSString *operation = [NSString stringWithFormat:@"%@ %@",HTTPMethod,self.url.path];
    FTStatus status = isError? FTStatusOk:FTStatusError;
    NSString *statusStr = [FTBaseInfoHandler statusStrWithStatus:status];
    
    NSMutableDictionary *tags = @{FT_KEY_OPERATION:operation,
                                  FT_TRACING_STATUS:statusStr,
                                  FT_KEY_SPANTYPE:FT_SPANTYPE_ENTRY,
                                  FT_TYPE_RESOURCE:operation,
                                  FT_TYPE:@"custom",
    }.mutableCopy;
    NSDictionary *fields = @{FT_KEY_DURATION:[FTDateUtil nanosecondTimeIntervalSinceDate:self.startTime toDate:[NSDate date]]};
    [tags addEntriesFromDictionary:[self getTraceSpanID]];
    [tags setValue:[FTNetworkTrace sharedInstance].service forKey:FT_KEY_SERVICE];
    [self tracingContent:content tags:tags fields:fields];
}

-(void)rumUploadResourceWithContentModel:(FTResourceContentModel *)model isError:(BOOL)isError{
    if (!self.url) {
        return;
    }
   //公共 tags
    NSString *url_path_group = [FTBaseInfoHandler replaceNumberCharByUrl:self.task.originalRequest.URL];
    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:@{
        @"resource_url":self.url.absoluteString,
        @"resource_url_host":self.url.host,
        @"resource_url_path":self.url.path,
        @"resource_url_path_group":url_path_group
    }];
    // trace 开启 enableLinkRumData 时 添加 span_id、trace_id tag
    if (self.isSampling && [FTNetworkTrace sharedInstance].enableLinkRumData) {
        [tags addEntriesFromDictionary:[self getTraceSpanID]];
    }
    if (isError) {
        NSInteger code = model.httpStatusCode == 0?:model.errorCode;
        NSString *run = [FTMonitorManager sharedInstance].running?@"run":@"startup";
        NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithDictionary:[model getResourceErrorFields]];
        [fields setValue:[NSString stringWithFormat:@"[%ld][%@]",(long)code,self.url.absoluteString] forKey:@"error_message"];
        [tags setValue:run forKey:@"error_situation"];
        [tags addEntriesFromDictionary:[model getResourceErrorTags]];
        [[FTMonitorManager sharedInstance].rumManger resourceError:self.identifier tags:tags fields:fields time:self.endTime];
    }else{
        [tags setValue:[self getResourceStatusGroup:model.httpStatusCode] forKey:@"resource_status_group"];
        [tags setValue:[self.url query] forKey:@"resource_url_query"];
        [tags addEntriesFromDictionary:[model getResourceSuccessTags]];
        NSDictionary *fields = [model getResourceSuccessFields];
        if (model.duration == @0) {
            model.duration = [FTDateUtil nanosecondTimeIntervalSinceDate:self.startTime toDate:self.endTime];
        }
        [[FTMonitorManager sharedInstance].rumManger resourceSuccess:self.identifier tags:tags fields:[model getResourceSuccessFields] time:self.endTime];
    }
}
- (void)stopResource{
    [[FTMonitorManager sharedInstance].rumManger stopResource:self.identifier];
}
#pragma mark - private -
-(void)tracingContent:(NSString *)content tags:(NSDictionary *)tags fields:(NSDictionary *)fields{
    if (self.isSampling) {
    NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:tags];
    [newTags addEntriesFromDictionary:[self getTraceSpanID]];
    [newTags setValue:[FTNetworkTrace sharedInstance].service forKey:FT_KEY_SERVICE];
    [[FTMobileAgent sharedInstance] tracing:content tags:newTags field:fields tm:[FTDateUtil dateTimeNanosecond:self.startTime]];
    }
}
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
- (NSString *)getResourceStatusGroup:(NSInteger )status{
    if (status>=0 && status<1000) {
        NSInteger a = status/100;
        return  [NSString stringWithFormat:@"%ldxx",(long)a];
    }
    return nil;
}
-(NSDate *)endTime{
    if (!_endTime) {
        _endTime = [NSDate date];
    }
    return _endTime;
}
- (void)dealResourceDatas{

    NSURLSessionTaskTransactionMetrics *taskMes = [self.metrics.transactionMetrics lastObject];

    [self traceRequest:self.task.currentRequest response:(NSHTTPURLResponse *)self.task.response startDate:taskMes.requestStartDate taskDuration:[NSNumber numberWithInt:[self.metrics.taskInterval duration]*1000000] error:self.error];
    
    [self rumDataWrite];
    [self stopResource];
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

//rum resourceStart
-(void)startResource{

    [[FTMonitorManager sharedInstance].rumManger startResource:self.identifier];
}
- (void)rumDataWrite{
    //  RUM 未开启时 rumManger == nil
    if (![FTMonitorManager sharedInstance].rumManger) {
        return;
    }
    FTResourceContentModel *model = [[FTResourceContentModel alloc]init];
    NSURLSessionTaskTransactionMetrics *taskMes = [self.metrics.transactionMetrics lastObject];
    self.endTime = taskMes.responseEndDate;
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)self.task.response;
    NSError *error = self.error?:response.ft_getResponseError;
    model.setHttpMethod(self.task.originalRequest.HTTPMethod);
    if(error){
        model.errorCode = error.code;
        model.responseData = self.data;
        [self rumUploadResourceWithContentModel:model isError:YES];
    }else{
        NSNumber *dnsTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.domainLookupEndDate];
        NSNumber *tcpTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.connectStartDate toDate:taskMes.connectEndDate];
        
        NSNumber *tlsTime = taskMes.secureConnectionStartDate!=nil ? [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.secureConnectionStartDate toDate:taskMes.connectEndDate]:@0;
        NSNumber *ttfbTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseStartDate];
        NSNumber *transTime =[FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseEndDate];
        NSNumber *durationTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.fetchStartDate toDate:taskMes.requestEndDate];
        NSNumber *resourceFirstByteTime = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.responseStartDate];
        model.setResourceType(response.MIMEType)
        .setHttpStatusCode(response.statusCode)
        .setResource_first_byte(resourceFirstByteTime)
        .setResource_size([NSNumber numberWithLongLong:self.task.countOfBytesReceived+[response ft_getResponseHeaderDataSize]])
        .setResource_dns(dnsTime)
        .setResource_tcp(tcpTime)
        .setResource_ssl(tlsTime)
        .setResource_ttfb(ttfbTime)
        .setResource_trans(transTime)
        .setDuration(durationTime);
        [self rumUploadResourceWithContentModel:model isError:NO];
    }

}
@end
