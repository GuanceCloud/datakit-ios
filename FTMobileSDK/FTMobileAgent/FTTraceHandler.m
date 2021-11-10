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
@property (nonatomic, strong) NSNumber *duration;

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
        self.duration = @0;
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
-(void)tracingContent:(NSString *)content operationName:(NSString *)operationName isError:(BOOL)isError{
    if(!content){
        return;
    }
    if (self.isSampling) {
        FTStatus status = isError? FTStatusError:FTStatusOk;
    NSString *statusStr = FTStatusStringMap[status];
    
    NSMutableDictionary *tags = @{FT_KEY_OPERATION:operationName,
                                  FT_TRACING_STATUS:statusStr,
                                  FT_KEY_SPANTYPE:FT_SPANTYPE_ENTRY,
                                  FT_TYPE_RESOURCE:operationName,
                                  FT_TYPE:@"custom",
    }.mutableCopy;
    NSDictionary *fields = @{FT_KEY_DURATION:[self.duration intValue]>0?self.duration:[FTDateUtil nanosecondTimeIntervalSinceDate:self.startTime toDate:[NSDate date]]};
    [tags addEntriesFromDictionary:[self getTraceSpanID]];
    [tags setValue:[FTNetworkTrace sharedInstance].service forKey:FT_KEY_SERVICE];
    [[FTMobileAgent sharedInstance] tracing:content tags:tags field:fields tm:[FTDateUtil dateTimeNanosecond:self.startTime]];
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
-(NSString *)getSpanID{
    return self.span_id;
}
-(NSString *)getTraceID{
    return self.trace_id;
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

- (void)traceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error{
    if (start) {
        self.startTime = start;
    }
    self.duration = duration;
    NSDictionary *responseDict = @{};
    BOOL isError = NO;
    if (error) {
        isError = YES;
        NSString *errorDescription=[[error.userInfo allKeys] containsObject:@"NSLocalizedDescription"]?error.userInfo[@"NSLocalizedDescription"]:@"";
        NSNumber *errorCode = [NSNumber numberWithInteger:error.code];
        responseDict = @{FT_NETWORK_HEADERS:@{},
                         FT_NETWORK_ERROR:@{@"errorCode":errorCode,
                                            @"errorDomain":error.domain,
                                            @"errorDescription":errorDescription,
                         },
        };
    }else{
        if( [[response ft_getResponseStatusCode] integerValue] >=400){
            isError = YES;
        }
        responseDict = response?[response ft_getResponseDict]:responseDict;
    }
    NSMutableDictionary *requestDict = [request ft_getRequestContentDict].mutableCopy;
    NSDictionary *responseDic = responseDict?responseDict:@{};
    NSDictionary *content = @{
        FT_NETWORK_RESPONSE_CONTENT:responseDic,
        FT_NETWORK_REQUEST_CONTENT:requestDict
    };
    NSString *operation = [request ft_getOperationName];
    [self tracingContent:[FTJSONUtil convertToJsonData:content] operationName:operation isError:isError];
}
@end
