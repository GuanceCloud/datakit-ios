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
    if (!_requestHeader) {
        self.requestHeader = [[FTNetworkTrace sharedInstance] networkTrackHeaderWithUrl:self.url];
    }
    return _requestHeader;
}
-(void)tracingWithModel:(FTResourceContentModel *)model{
    if (!self.isSampling) {
        return;
    }
    model.url = model.url?:self.url;
    NSDictionary *responseDict = @{};
    BOOL isError = NO;
    if (model.error || model.errorMessage) {
        isError = YES;
        if (model.error) {
            NSString *errorDescription=[[model.error.userInfo allKeys] containsObject:@"NSLocalizedDescription"]?model.error.userInfo[@"NSLocalizedDescription"]:@"";
            NSNumber *errorCode = [NSNumber numberWithInteger:model.error.code];
            responseDict = @{FT_NETWORK_HEADERS:@{},
                             FT_NETWORK_ERROR:@{@"errorCode":errorCode,
                                                @"errorDomain":model.error.domain,
                                                @"errorDescription":errorDescription,
                             },
            };
        }else{
            responseDict = @{FT_NETWORK_HEADERS:@{},
                             FT_NETWORK_ERROR:model.errorMessage,
            };
        }
    }else{
        if(model.httpStatusCode<0 || model.httpStatusCode >=400){
            isError = YES;
        }
        if(model.responseHeader && model.httpStatusCode){
            responseDict = @{FT_NETWORK_HEADERS:model.responseHeader,
                             FT_NETWORK_CODE:@(model.httpStatusCode)
            };
        }
    }
    NSMutableDictionary *requestDict =@{@"method":model.httpMethod,
                                        FT_NETWORK_HEADERS:model.requestHeader,
                                        @"url":model.url.absoluteString,
    }.mutableCopy;;
    NSDictionary *content = @{
        FT_NETWORK_RESPONSE_CONTENT:responseDict,
        FT_NETWORK_REQUEST_CONTENT:requestDict
    };
    NSString *operationName = [NSString stringWithFormat:@"%@ %@",model.httpMethod,model.url.path];
    NSString *contentStr = [FTJSONUtil convertToJsonData:content];
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
    [[FTMobileAgent sharedInstance] tracing:contentStr tags:tags field:fields tm:[FTDateUtil dateTimeNanosecond:self.startTime]];
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
@end
