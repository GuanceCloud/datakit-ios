//
//  FTTraceHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTTraceHandler.h"
#import "FTBaseInfoHandler.h"
#import "FTGlobalRumManager.h"
#import "FTMobileAgent+Private.h"
#import "FTDateUtil.h"
#import "FTNetworkTraceManager.h"
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
        self.requestHeader = [[FTNetworkTraceManager sharedInstance] networkTrackHeaderWithUrl:self.url];
    }
    return _requestHeader;
}
#pragma mark - private -
-(void)setRequestHeader:(NSDictionary *)requestHeader{
    _requestHeader = requestHeader;
    [self resolveRequestHeader];
}
- (void)resolveRequestHeader{
    __weak typeof(self) weakSelf = self;
    [[FTNetworkTraceManager sharedInstance] getTraceingDatasWithRequestHeaderFields:self.requestHeader handler:^(NSString * _Nonnull traceId, NSString * _Nonnull spanID, BOOL sampled) {
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
        return @{FT_KEY_SPANID:self.span_id,
                 FT_KEY_TRACEID:self.trace_id
        };
    }else{
        return nil;
    }
}
@end
