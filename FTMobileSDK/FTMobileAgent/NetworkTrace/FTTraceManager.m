//
//  FTTraceManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTTraceManager.h"
#import "FTNetworkInfoManager.h"
#import "FTTraceHandler.h"
#import "FTConfigManager.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
#import "FTDateUtil.h"
NSString * const FT_TRACR_IDENTIFIER = @"ft_identifier";

@interface FTTraceManager ()
@property (nonatomic,copy) NSString *sdkUrlStr;
@property (nonatomic, strong) NSMutableDictionary<NSString *,FTTraceHandler *> *traceHandlers;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) BOOL enableLinkRumData;
@end
@implementation FTTraceManager
+ (instancetype)sharedInstance {
    static FTTraceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.sdkUrlStr = [FTNetworkInfoManager sharedInstance].metricsUrl;
        self.lock = dispatch_semaphore_create(1);
        self.traceHandlers = [NSMutableDictionary new];
    }
    return self;
}
-(BOOL)enableAutoTrace{
    return [FTConfigManager sharedInstance].traceConfig.enableAutoTrace;
}
-(BOOL)enableLinkRumData{
    return  [FTConfigManager sharedInstance].traceConfig.enableLinkRumData;
}
- (BOOL)isInternalURL:(NSURL *)url{
    if (self.sdkUrlStr) {
        if (url.port) {
            return ([url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host]&&[url.port isEqual:[NSURL URLWithString:self.sdkUrlStr].port]);
        }else{
            return [url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host];
        }
    }
    return NO;
}
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    FTTraceHandler *handler = [self getTraceHandler:key];
    if (!handler) {
        handler = [[FTTraceHandler alloc]initWithUrl:url identifier:key];
        if(self.enableLinkRumData){
            [self setTraceHandler:handler forKey:key];
        }
    }
    return handler.getTraceHeader;
}
- (void)setTraceHandler:(FTTraceHandler *)handler forKey:(NSString *)key{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.traceHandlers setValue:handler forKey:key];
    dispatch_semaphore_signal(self.lock);
}
// 因为不涉及 trace 数据写入 调用-getTraceHandler方法的仅是 rum 操作 需要确保 rum 调用此方法
- (FTTraceHandler *)getTraceHandler:(NSString *)key{
    FTTraceHandler *handler = nil;
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    if ([self.traceHandlers.allKeys containsObject:key]) {
      handler = self.traceHandlers[key];
      [self.traceHandlers removeObjectForKey:key];
    }
    dispatch_semaphore_signal(self.lock);
    return handler;
}
#pragma mark --------- URLSessionInterceptorType ----------
- (NSURLRequest *)injectTraceHeader:(NSURLRequest *)request{
    //判断是否开启 trace ，是否是内部 url
    if (![self enableAutoTrace] || [self isInternalURL:request.URL]) {
        return request;
    }
    if ([request.allHTTPHeaderFields.allKeys containsObject:FT_TRACR_IDENTIFIER]) {
        return request;
    }
    NSString *identifier =  [NSUUID UUID].UUIDString;
    NSDictionary *traceHeader = [self getTraceHeaderWithKey:identifier url:request.URL];
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    if (traceHeader && traceHeader.allKeys.count>0) {
        [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
            [mutableReqeust setValue:value forHTTPHeaderField:field];
        }];
        [mutableReqeust setValue:identifier forHTTPHeaderField:FT_TRACR_IDENTIFIER];
    }
    return mutableReqeust;
}
- (void)taskCreated:(NSURLSessionTask *)task session:(NSURLSession *)session{
    if ([self isInternalURL:task.originalRequest.URL]) {
        return;
    }
    NSString *identifier = task.originalRequest.allHTTPHeaderFields[FT_TRACR_IDENTIFIER];
    if (self.rumDelegate && [self.rumDelegate respondsToSelector:@selector(startResourceWithKey:)]) {
        [self.rumDelegate startResourceWithKey:identifier];
    }
}
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics{
    if ([self isInternalURL:task.originalRequest.URL]) {
        return;
    }
    NSString *identifier = task.originalRequest.allHTTPHeaderFields[FT_TRACR_IDENTIFIER];
    FTTraceHandler *handler = [self getTraceHandler:identifier];
    handler.metrics = metrics;
}
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data{
    if ([self isInternalURL:task.originalRequest.URL]) {
        return;
    }
    NSString *identifier = task.originalRequest.allHTTPHeaderFields[FT_TRACR_IDENTIFIER];
    FTTraceHandler *handler = [self getTraceHandler:identifier];
    handler.data = data;
}
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    if ([self isInternalURL:task.originalRequest.URL]) {
        return;
    }
    NSString *identifier = task.originalRequest.allHTTPHeaderFields[FT_TRACR_IDENTIFIER];
    FTTraceHandler *handler = [self getTraceHandler:identifier];
    
    NSNumber *duration = [FTDateUtil nanosecondTimeIntervalSinceDate:handler.startTime toDate:[NSDate date]];
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = task.originalRequest.URL;
    model.requestHeader = task.originalRequest.allHTTPHeaderFields;
    model.httpMethod = task.originalRequest.HTTPMethod;
    NSHTTPURLResponse *response =(NSHTTPURLResponse *)task.response;
    if (response) {
        NSDictionary *responseHeader = response.allHeaderFields;
        model.responseHeader = responseHeader;
        model.httpStatusCode = response.statusCode;
        if (handler.data) {
            model.responseBody = [[NSString alloc] initWithData:handler.data encoding:NSUTF8StringEncoding];
        }
    }
    model.error = error;
    model.duration = duration;
    FTResourceMetricsModel *metricsModel = nil;
    if (@available(iOS 10.0, *)) {
        if (handler.metrics) {
            metricsModel = [[FTResourceMetricsModel alloc]initWithTaskMetrics:handler.metrics];
        }
    }
    if (self.rumDelegate && [self.rumDelegate respondsToSelector:@selector(stopResourceWithKey:)]) {
        [self.rumDelegate stopResourceWithKey:identifier];
    }
    if (self.rumDelegate && [self.rumDelegate respondsToSelector:@selector(addResourceWithKey:metrics:content:)]) {
        [self.rumDelegate addResourceWithKey:identifier metrics:metricsModel content:model];
    }
}
@end
