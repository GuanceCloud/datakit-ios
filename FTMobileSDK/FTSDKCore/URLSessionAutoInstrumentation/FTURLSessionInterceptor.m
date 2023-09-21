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
#import <objc/runtime.h>

@interface FTURLSessionInterceptor ()
@property (nonatomic, strong) NSMutableDictionary <id,FTTraceHandler *> *traceHandlers;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) BOOL enableLinkRumData;
@property (nonatomic, assign) BOOL enableTrace;
@property (nonatomic, weak) id<FTTracerProtocol> tracer;
@end
@implementation FTURLSessionInterceptor
@synthesize innerResourceHandeler = _innerResourceHandeler;
@synthesize innerUrl = _innerUrl;
@synthesize enableAutoRumTrack = _enableAutoRumTrack;
@synthesize intakeUrlHandler = _intakeUrlHandler;

-(instancetype)init{
    self = [super init];
    if (self) {
        _lock = dispatch_semaphore_create(1);
        _traceHandlers = [NSMutableDictionary new];
        _enableTrace = NO;
        _enableLinkRumData = NO;
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
- (BOOL)isTraceUrl:(NSURL *)url{
    BOOL trace = YES;
    if (self.innerUrl) {
        if (url.port) {
            trace = !([url.host isEqualToString:[NSURL URLWithString:self.innerUrl].host]&&[url.port isEqual:[NSURL URLWithString:self.innerUrl].port]);
        }else{
            trace = ![url.host isEqualToString:[NSURL URLWithString:self.innerUrl].host];
        }
        if(trace && self.intakeUrlHandler){
            return self.intakeUrlHandler(url);
        }
    }
    return trace;
}
/**
 * 内部采集以 task 为 key
 * 外部传传入为 NSString 类型的 key
 */
- (void)setTraceHandler:(FTTraceHandler *)handler forKey:(id)key{
    if (key == nil) {
        return;
    }
    [self.traceHandlers setObject:handler forKey:key];
}
// 因为不涉及 trace 数据写入 调用-getTraceHandler方法的仅是 rum 操作 需要确保 rum 调用此方法
- (FTTraceHandler *)getTraceHandler:(id)key{
    if (key == nil) {
        return nil;
    }
    return [self.traceHandlers objectForKey:key];
}
-(void)removeTraceHandlerWithKey:(id)key{
    if (key == nil) {
        return;
    }
    [self.traceHandlers removeObjectForKey:key];
}
#pragma mark --------- URLSessionInterceptorType ----------
-(void)setInnerUrl:(NSString *)innerUrl{
    _innerUrl = innerUrl;
}
-(NSString *)innerUrl{
    return _innerUrl;
}
-(void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler{
    _intakeUrlHandler = intakeUrlHandler;
}
-(FTIntakeUrl)intakeUrlHandler{
    return _intakeUrlHandler;
}
-(void)setEnableAutoRumTrack:(BOOL)enableAutoRumTrack{
    _enableAutoRumTrack = enableAutoRumTrack;
}
-(BOOL)enableAutoRumTrack{
    return _enableAutoRumTrack;
}
-(void)setInnerResourceHandeler:(id<FTRumResourceProtocol>)innerResourceHandeler{
    _innerResourceHandeler = innerResourceHandeler;
}
-(id<FTRumResourceProtocol>)innerResourceHandeler{
    return _innerResourceHandeler;
}
- (NSURLRequest *)injectTraceHeader:(NSURLRequest *)request{
    //判断是否开启 trace ，是否是要采集的url
    if (!self.enableTrace) {
        return request;
    }
    NSDictionary *traceHeader = [self.tracer networkTraceHeaderWithUrl:request.URL];
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    if (traceHeader && traceHeader.allKeys.count>0) {
        [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
            [mutableReqeust setValue:value forHTTPHeaderField:field];
        }];
    }
    return mutableReqeust;
}
- (void)taskCreated:(NSURLSessionTask *)task session:(NSURLSession *)session{
    FTTraceHandler *handler = [[FTTraceHandler alloc]initWithUrl:task.currentRequest.URL identifier:[NSUUID UUID].UUIDString];
    [self setTraceHandler:handler forKey:task];
    
    [self startResourceWithKey:handler.identifier];
}
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    FTTraceHandler *handler = [self getTraceHandler:task];
    if(!handler){
        return;
    }
    [handler taskReceivedMetrics:metrics];
}
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data{
    FTTraceHandler *handler = [self getTraceHandler:task];
    if(!handler){
        return;
    }
    [handler taskReceivedData:data];
}
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    FTTraceHandler *handler = [self getTraceHandler:task];
    if(!handler){
        return;
    }
    [handler taskCompleted:task error:error];
    [self removeTraceHandlerWithKey:task];
    [self stopResourceWithKey:handler.identifier];
    __block NSString *span_id = nil,*trace_id=nil;
    if (self.enableLinkRumData) {
        
        [self.tracer unpackTraceHeader:task.currentRequest.allHTTPHeaderFields handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            span_id = spanID;
            trace_id = traceId;
        }];
    }
    [self addResourceWithKey:handler.identifier metrics:handler.metricsModel content:handler.contentModel spanID:span_id traceID:trace_id];
}

#pragma mark --------- external data ----------
-(NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    __block FTTraceHandler *handler = [[FTTraceHandler alloc]initWithUrl:url identifier:key];
    NSDictionary *dict = nil;
    if(self.enableLinkRumData){
       dict  = [self.tracer networkTraceHeaderWithUrl:url handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            handler.traceID = traceId;
            handler.spanID = spanID;
        }];
        [self setTraceHandler:handler forKey:key];
    }
    else{
        dict = [self.tracer networkTraceHeaderWithUrl:url];
    }
    return  dict;
}
- (void)startResourceWithKey:(NSString *)key{
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(startResourceWithKey:)]) {
        [self.innerResourceHandeler startResourceWithKey:key];
    }
}
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property{
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(startResourceWithKey:property:)]) {
        [self.innerResourceHandeler startResourceWithKey:key property:property];
    }
}
- (void)stopResourceWithKey:(nonnull NSString *)key{
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(stopResourceWithKey:)]) {
        [self.innerResourceHandeler stopResourceWithKey:key];
    }
}
-(void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(stopResourceWithKey:property:)]) {
        [self.innerResourceHandeler stopResourceWithKey:key property:property];
    }
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    FTTraceHandler *handler = [self getTraceHandler:key];
    [self removeTraceHandlerWithKey:key];
    [self addResourceWithKey:key metrics:metrics content:content spanID:handler.spanID traceID:handler.traceID];
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID{
    [self removeTraceHandlerWithKey:key];
    if (self.innerResourceHandeler && [self.innerResourceHandeler respondsToSelector:@selector(addResourceWithKey:metrics:content:spanID:traceID:)]) {
        [self.innerResourceHandeler addResourceWithKey:key metrics:metrics content:content spanID:spanID traceID:traceID];
    }
}



@end
