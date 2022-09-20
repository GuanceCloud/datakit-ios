//
//  FTURLSessionInterceptor.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTURLSessionInterceptor.h"
#import "FTTraceHandler.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel.h"
#import "FTDateUtil.h"
#import <objc/runtime.h>

@interface FTURLSessionInterceptor ()
@property (nonatomic, strong) NSMutableDictionary<id,FTTraceHandler *> *traceHandlers;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) BOOL enableLinkRumData;
@property (nonatomic, assign) BOOL enableRumTrack;
@property (nonatomic, assign) BOOL enableTrace;
@property (nonatomic, weak) id<FTTracerProtocol> tracer;
@end
@implementation FTURLSessionInterceptor
@synthesize innerResourceHandeler = _innerResourceHandeler;
@synthesize innerUrl = _innerUrl;

+ (instancetype)sharedInstance {
    static FTURLSessionInterceptor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        _lock = dispatch_semaphore_create(1);
        _traceHandlers = [NSMutableDictionary new];
        _enableTrace = NO;
        _enableLinkRumData = NO;
        _enableRumTrack = NO;
    }
    return self;
}
- (void)setTracer:(id<FTTracerProtocol>)tracer{
    _tracer = tracer;
}
-(void)enableAutoTrace:(BOOL)enable{
    self.enableTrace = enable;
}
-(void)enableLinkRumData:(BOOL)enable{
    self.enableLinkRumData = enable;
}
-(void)enableRumTrack:(BOOL)enable{
    self.enableRumTrack = enable;
}
- (BOOL)isInternalURL:(NSURL *)url{
    if (self.innerUrl) {
        if (url.port) {
            return ([url.host isEqualToString:[NSURL URLWithString:self.innerUrl].host]&&[url.port isEqual:[NSURL URLWithString:self.innerUrl].port]);
        }else{
            return [url.host isEqualToString:[NSURL URLWithString:self.innerUrl].host];
        }
    }
    return NO;
}
// traceHandler 处理
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    return [self.tracer networkTraceHeaderWithUrl:url];
}
/**
 * 内部采集以 task 为 key
 * 外部传传入为 NSString 类型的 key
 */
- (void)setTraceHandler:(FTTraceHandler *)handler forKey:(id)key{
    if (key == nil) {
        return;
    }
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.traceHandlers setValue:handler forKey:key];
    dispatch_semaphore_signal(self.lock);
}
// 因为不涉及 trace 数据写入 调用-getTraceHandler方法的仅是 rum 操作 需要确保 rum 调用此方法
- (FTTraceHandler *)getTraceHandler:(id)key{
    if (key == nil) {
        return nil;
    }
    FTTraceHandler *handler = nil;
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    if ([self.traceHandlers.allKeys containsObject:key]) {
      handler = self.traceHandlers[key];
    }
    dispatch_semaphore_signal(self.lock);
    return handler;
}
-(void)removeTraceHandlerWithKey:(id)key{
    if (key == nil) {
        return;
    }
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.traceHandlers removeObjectForKey:key];
    dispatch_semaphore_signal(self.lock);
}
#pragma mark --------- URLSessionInterceptorType ----------
-(void)setInnerUrl:(NSString *)innerUrl{
    _innerUrl = innerUrl;
}
-(NSString *)innerUrl{
    return _innerUrl;
}
-(void)setInnerResourceHandeler:(id<FTRumInnerResourceProtocol>)innerResourceHandeler{
    _innerResourceHandeler = innerResourceHandeler;
}
-(id<FTRumInnerResourceProtocol>)innerResourceHandeler{
    return _innerResourceHandeler;

}
- (NSURLRequest *)injectTraceHeader:(NSURLRequest *)request{
    //判断是否开启 trace ，是否是内部 url
    if (!self.enableTrace || [self isInternalURL:request.URL]) {
        return request;
    }
    NSDictionary *traceHeader = [self getTraceHeaderWithKey:@"" url:request.URL];
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    if (traceHeader && traceHeader.allKeys.count>0) {
        [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
            [mutableReqeust setValue:value forHTTPHeaderField:field];
        }];
    }
    return mutableReqeust;
}
- (void)taskCreated:(NSURLSessionTask *)task session:(NSURLSession *)session{
    if (!self.enableRumTrack || [self isInternalURL:task.originalRequest.URL] ) {
        return;
    }
    FTTraceHandler *handler = [[FTTraceHandler alloc]initWithUrl:task.currentRequest.URL identifier:[NSUUID UUID].UUIDString];
    [self setTraceHandler:handler forKey:task];
    
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(startResourceWithKey:)]) {
        [self.innerResourceHandeler startResourceWithKey:handler.identifier];
    }
}
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics{
    if (!self.enableRumTrack || [self isInternalURL:task.originalRequest.URL]) {
        return;
    }
    FTTraceHandler *handler = [self getTraceHandler:task];
    [handler taskReceivedMetrics:metrics];
}
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data{
    if (!self.enableRumTrack || [self isInternalURL:task.originalRequest.URL]) {
        return;
    }
    FTTraceHandler *handler = [self getTraceHandler:task];
    [handler taskReceivedData:data];
}
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    if (!self.enableRumTrack || [self isInternalURL:task.originalRequest.URL]) {
        return;
    }
    FTTraceHandler *handler = [self getTraceHandler:task];
    [handler taskCompleted:task error:error];
    [self removeTraceHandlerWithKey:task];
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(stopResourceWithKey:)]) {
        [self.innerResourceHandeler stopResourceWithKey:handler.identifier];
    }
    if (self.enableLinkRumData) {
        if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(addResourceWithKey:metrics:content:spanID:traceID:)]) {
            __block NSString *span_id,*trace_id;
            [self.tracer unpackTraceHeader:task.currentRequest.allHTTPHeaderFields handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
                span_id = spanID;
                trace_id = traceId;
            }];
            [self.innerResourceHandeler addResourceWithKey:handler.identifier metrics:handler.metricsModel content:handler.contentModel spanID:span_id traceID:trace_id];
        }
    }else{
        if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(addResourceWithKey:metrics:content:)]) {
            [self.innerResourceHandeler addResourceWithKey:handler.identifier metrics:handler.metricsModel content:handler.contentModel];
        }
    }
}

#pragma mark --------- external data ----------
- (void)startResourceWithKey:(NSString *)key{
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(startResourceWithKey:)]) {
        [self.innerResourceHandeler startResourceWithKey:key];
    }
}
- (void)stopResourceWithKey:(nonnull NSString *)key{
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(stopResourceWithKey:)]) {
        [self.innerResourceHandeler stopResourceWithKey:key];
    }
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    [self removeTraceHandlerWithKey:key];
    if (self.enableLinkRumData) {
        if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(addResourceWithKey:metrics:content:spanID:traceID:)]) {
            __block NSString *span_id,*trace_id;
            [self.tracer unpackTraceHeader:content.requestHeader handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
                span_id = spanID;
                trace_id = traceId;
            }];
            [self.innerResourceHandeler addResourceWithKey:key metrics:metrics content:content spanID:span_id traceID:trace_id];
        }
    }else{
        if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(addResourceWithKey:metrics:content:)]) {
            [self.innerResourceHandeler addResourceWithKey:key metrics:metrics content:content];
        }
    }
}


@end
