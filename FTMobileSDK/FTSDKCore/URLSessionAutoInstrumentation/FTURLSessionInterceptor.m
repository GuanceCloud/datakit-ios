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
#import "FTReadWriteHelper.h"
@interface FTURLSessionInterceptor ()
@property (nonatomic, strong) FTReadWriteHelper<NSMutableDictionary <id,FTTraceHandler *>*> *traceHandlers;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, weak) id<FTTracerProtocol> tracer;
@end
@implementation FTURLSessionInterceptor
@synthesize rumResourceHandeler = _rumResourceHandeler;
@synthesize intakeUrlHandler = _intakeUrlHandler;
static FTURLSessionInterceptor *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)shared{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        _traceHandlers = [[FTReadWriteHelper alloc]initWithValue:[NSMutableDictionary new]];
    }
    return self;
}
- (void)setTracer:(id<FTTracerProtocol>)tracer{
    _tracer = tracer;
}
- (BOOL)isTraceUrl:(NSURL *)url{
    if(self.intakeUrlHandler){
        return self.intakeUrlHandler(url);
    }
    return YES;
}
/**
 * 内部采集以 task 为 key
 * 外部传传入为 NSString 类型的 key
 */
- (void)setTraceHandler:(FTTraceHandler *)handler forKey:(id)key{
    if (key == nil) {
        return;
    }
    [self.traceHandlers concurrentWrite:^(NSMutableDictionary<id,FTTraceHandler *> * _Nonnull value) {
        [value setValue:handler forKey:key];
    }];
}
// 因为不涉及 trace 数据写入 调用-getTraceHandler方法的仅是 rum 操作 需要确保 rum 调用此方法
- (FTTraceHandler *)getTraceHandler:(id)key{
    if (key == nil) {
        return nil;
    }
    __block FTTraceHandler *handler;
    [self.traceHandlers concurrentRead:^(NSMutableDictionary<id,FTTraceHandler *> * _Nonnull value) {
        handler = [value objectForKey:key];
    }];
    return handler;
}
-(void)removeTraceHandlerWithKey:(id)key{
    if (key == nil) {
        return;
    }
    [self.traceHandlers concurrentWrite:^(NSMutableDictionary<id,FTTraceHandler *> * _Nonnull value) {
        [value removeObjectForKey:key];
    }];
}
#pragma mark --------- URLSessionInterceptorType ----------
-(void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler{
    _intakeUrlHandler = intakeUrlHandler;
}
-(FTIntakeUrl)intakeUrlHandler{
    return _intakeUrlHandler;
}
-(void)setRumResourceHandeler:(id<FTRumResourceProtocol>)innerResourceHandeler{
    _rumResourceHandeler = innerResourceHandeler;
}
-(id<FTRumResourceProtocol>)rumResourceHandeler{
    return _rumResourceHandeler;
}
- (void)taskCreated:(NSURLSessionTask *)task{
    FTTraceHandler *handler = [[FTTraceHandler alloc]init];
    [self setTraceHandler:handler forKey:task];
    [self startResourceWithKey:handler.identifier];
}
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request{
    NSDictionary *traceHeader = [self.tracer networkTraceHeaderWithUrl:request.URL];
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    if (traceHeader && traceHeader.allKeys.count>0) {
        [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
            [mutableReqeust setValue:value forHTTPHeaderField:field];
        }];
    }
    return mutableReqeust;
}
- (void)interceptTask:(NSURLSessionTask *)task{
    if(!task.originalRequest){
        return;
    }
    FTTraceHandler *handler = [self getTraceHandler:task];
    if(!handler){
        FTTraceHandler *handler = [[FTTraceHandler alloc]init];
        handler.request = task.originalRequest;
        [self setTraceHandler:handler forKey:task];
        [self startResourceWithKey:handler.identifier];
    }
}
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics{
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
    NSDictionary *property;
    if(self.provider){
         property = self.provider(handler.request, handler.response, handler.data, handler.error);
    }
    [self stopResourceWithKey:handler.identifier property:property];
    __block NSString *span_id = nil,*trace_id=nil;
    if (self.tracer.enableLinkRumData) {
        [self.tracer unpackTraceHeader:task.currentRequest.allHTTPHeaderFields handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            span_id = spanID;
            trace_id = traceId;
        }];
    }
    [self addResourceWithKey:handler.identifier metrics:handler.metricsModel content:handler.contentModel spanID:span_id traceID:trace_id];
}

#pragma mark --------- external data ----------
-(NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    __block FTTraceHandler *handler = [[FTTraceHandler alloc]initWithIdentifier:key];
    NSDictionary *dict = nil;
    if(self.tracer.enableLinkRumData){
       dict = [self.tracer networkTraceHeaderWithUrl:url handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
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
    if (self.rumResourceHandeler && [self.rumResourceHandeler respondsToSelector:@selector(startResourceWithKey:)]) {
        [self.rumResourceHandeler startResourceWithKey:key];
    }
}
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property{
    if (self.rumResourceHandeler && [self.rumResourceHandeler respondsToSelector:@selector(startResourceWithKey:property:)]) {
        [self.rumResourceHandeler startResourceWithKey:key property:property];
    }
}
- (void)stopResourceWithKey:(nonnull NSString *)key{
    if (self.rumResourceHandeler && [self.rumResourceHandeler respondsToSelector:@selector(stopResourceWithKey:)]) {
        [self.rumResourceHandeler stopResourceWithKey:key];
    }
}
-(void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    if (self.rumResourceHandeler && [self.rumResourceHandeler respondsToSelector:@selector(stopResourceWithKey:property:)]) {
        [self.rumResourceHandeler stopResourceWithKey:key property:property];
    }
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    FTTraceHandler *handler = [self getTraceHandler:key];
    [self removeTraceHandlerWithKey:key];
    [self addResourceWithKey:key metrics:metrics content:content spanID:handler.spanID traceID:handler.traceID];
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID{
    [self removeTraceHandlerWithKey:key];
    if (self.rumResourceHandeler && [self.rumResourceHandeler respondsToSelector:@selector(addResourceWithKey:metrics:content:spanID:traceID:)]) {
        [self.rumResourceHandeler addResourceWithKey:key metrics:metrics content:content spanID:spanID traceID:traceID];
    }
}
- (void)shutDown{
    onceToken = 0;
    sharedInstance =nil;
}
@end
