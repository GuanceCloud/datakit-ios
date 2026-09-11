//
//  FTURLSessionInterceptor.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTURLSessionInterceptor.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTSessionTaskHandler.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTReadWriteHelper.h"
#import "FTInnerLog.h"
#import "FTTraceContext.h"
#import "NSURLSessionTask+FTSwizzler.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTConstants.h"
#import "FTDateUtil.h"
#import "NSDate+FTUtil.h"
void *FTInterceptorQueueIdentityKey = &FTInterceptorQueueIdentityKey;

@interface FTURLSessionInterceptor ()
@property (nonatomic, strong) FTReadWriteHelper<NSMutableDictionary <id,FTSessionTaskHandler *>*> *traceHandlers;
@property (nonatomic, weak, nullable) id<FTTracerProtocol> tracer;
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@implementation FTURLSessionInterceptor
@synthesize rumResourceHandler = _rumResourceHandler;
@synthesize resourceUrlHandler = _resourceUrlHandler;
@synthesize intakeUrlHandler = _intakeUrlHandler;
@synthesize traceInterceptor = _traceInterceptor;
@synthesize resourcePropertyProvider = _resourcePropertyProvider;
@synthesize sessionTaskErrorFilter = _sessionTaskErrorFilter;

static FTURLSessionInterceptor *sharedInstance = nil;
static NSObject *sharedInstanceLock;
+ (void)initialize{
    if (self == [FTURLSessionInterceptor class]) {
        sharedInstanceLock = [[NSObject alloc] init];
    }
}
+ (instancetype)shared{
    @synchronized(sharedInstanceLock) {
        if (!sharedInstance) {
            sharedInstance = [[super allocWithZone:NULL] init];
        }
        return sharedInstance;
    }
}
-(instancetype)init{
    self = [super init];
    if (self) {
        _traceHandlers = [[FTReadWriteHelper alloc]initWithValue:[NSMutableDictionary new]];
        _queue = dispatch_queue_create("com.ft.network.interceptor", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue, FTInterceptorQueueIdentityKey, &FTInterceptorQueueIdentityKey, NULL);

    }
    return self;
}
- (BOOL)isTraceUrl:(NSURL *)url{
    if(self.resourceUrlHandler||self.intakeUrlHandler){
        if(!url){
            return NO;
        }
        if(self.resourceUrlHandler){
            return !self.resourceUrlHandler(url);
        }
        if(self.intakeUrlHandler){
            return self.intakeUrlHandler(url);
        }
    }
    return YES;
}
#pragma mark  ========== SessionTaskHandler ==========
/**
 * Internal collection uses task as key
 * External input uses NSString type key
 */
- (void)setTraceHandler:(FTSessionTaskHandler *)handler forKey:(id)key{
    if (key == nil) {
        return;
    }
    [self.traceHandlers concurrentWrite:^(NSMutableDictionary<id,FTSessionTaskHandler *> * _Nonnull value) {
        [value setValue:handler forKey:key];
    }];
}
// Since trace data writing is not involved, only rum operations call the -getTraceHandler method, need to ensure rum calls this method
- (FTSessionTaskHandler *)getTraceHandler:(id)key{
    if (key == nil) {
        return nil;
    }
    __block FTSessionTaskHandler *handler;
    [self.traceHandlers concurrentRead:^(NSMutableDictionary<id,FTSessionTaskHandler *> * _Nonnull value) {
        handler = [value objectForKey:key];
    }];
    return handler;
}
-(void)removeTraceHandlerWithKey:(id)key{
    if (key == nil) {
        return;
    }
    [self.traceHandlers concurrentWrite:^(NSMutableDictionary<id,FTSessionTaskHandler *> * _Nonnull value) {
        [value removeObjectForKey:key];
    }];
}
#pragma mark  ========== FTURLSessionInterceptorProtocol ==========
- (void)setTracer:(id<FTTracerProtocol>)tracer{
    _tracer = tracer;
}
-(void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler{
    _intakeUrlHandler = [intakeUrlHandler copy];
}
-(FTIntakeUrl)intakeUrlHandler{
    return _intakeUrlHandler;
}
-(void)setResourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler{
    _resourceUrlHandler = [resourceUrlHandler copy];
}
-(FTResourceUrlHandler)resourceUrlHandler{
    return _resourceUrlHandler;
}
-(void)setTraceInterceptor:(TraceInterceptor)traceInterceptor{
    _traceInterceptor = [traceInterceptor copy];
}
-(TraceInterceptor)traceInterceptor{
    return _traceInterceptor;
}
-(void)setResourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider{
    _resourcePropertyProvider = [resourcePropertyProvider copy];
}
-(ResourcePropertyProvider)resourcePropertyProvider{
    return _resourcePropertyProvider;
}
-(void)setRumResourceHandeler:(id<FTRumResourceProtocol>)innerResourceHandler{
    _rumResourceHandler = innerResourceHandler;
}
-(id<FTRumResourceProtocol>)rumResourceHandler{
    if(!_rumResourceHandler){
        FTInnerLogError(@"SDK configuration RUM error, RUM is not supported");
    }
    return _rumResourceHandler;
}
-(void)setSessionTaskErrorFilter:(SessionTaskErrorFilter)sessionTaskErrorFilter{
    _sessionTaskErrorFilter = [sessionTaskErrorFilter copy];
}
-(SessionTaskErrorFilter)sessionTaskErrorFilter{
    return _sessionTaskErrorFilter;
}
#pragma mark - trace
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request{
    NSURLRequest *backRequest = request;
    @try {
        if(_tracer&&_tracer.enableAutoTrace){
            NSMutableURLRequest *mutableRequest = [backRequest mutableCopy];
            NSDictionary *traceHeader = [self.tracer networkTraceHeaderWithUrl:request.URL];
            if (traceHeader && traceHeader.allKeys.count>0) {
                [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
                    [mutableRequest setValue:value forHTTPHeaderField:field];
                }];
            }
            backRequest = mutableRequest;
        }
    }@catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    return backRequest;
}
// trace:add trace header
- (void)traceInterceptTask:(NSURLSessionTask *)task{
    [self traceInterceptTask:task traceInterceptor:nil];
}
- (void)traceInterceptTask:(NSURLSessionTask *)task traceInterceptor:(nullable TraceInterceptor)traceInterceptor{
    @try {
        NSURLRequest *currentRequest = task.currentRequest;
        if(!currentRequest){
            return;
        }
        TraceInterceptor interceptor = traceInterceptor?:self.traceInterceptor;
        if(interceptor){
            FTTraceContext *context = interceptor(currentRequest);
            if (context != nil) {
                if (context.traceHeader && context.traceHeader.allKeys.count>0) {
                    NSMutableURLRequest *mutableRequest = [currentRequest mutableCopy];
                    [context.traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
                        [mutableRequest setValue:value forHTTPHeaderField:field];
                    }];
                    [task setValue:mutableRequest forKey:@"currentRequest"];
                }
                NSURL *resourceURL = task.ft_webSocketResourceURL ?: currentRequest.URL;
                [self traceInterceptTask:task linkTraceContext:context requestURL:resourceURL];
            }
            return;
        }else if(_tracer&&_tracer.enableAutoTrace){
            NSMutableURLRequest *mutableRequest = [currentRequest mutableCopy];
            NSDictionary *traceHeader = [self.tracer networkTraceHeaderWithUrl:mutableRequest.URL];
            if (traceHeader && traceHeader.allKeys.count>0) {
                [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
                    [mutableRequest setValue:value forHTTPHeaderField:field];
                }];
            }
            [task setValue:mutableRequest forKey:@"currentRequest"];
        }
    }@catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
- (void)traceInterceptTask:(NSURLSessionTask *)task linkTraceContext:(nullable FTTraceContext *)traceContext requestURL:(nullable NSURL *)requestURL{
    dispatch_async(self.queue, ^{
        @try {
            if(traceContext&&traceContext.spanId&&traceContext.traceId){
                if(!requestURL){
                    return;
                }
                if(![self isTraceUrl:requestURL]){
                    return;
                }
                FTSessionTaskHandler *handler = [self getTraceHandler:task];
                if(!handler){
                    handler = [[FTSessionTaskHandler alloc]init];
                    [self setTraceHandler:handler forKey:task];
                }
                handler.spanID = traceContext.spanId;
                handler.traceID = traceContext.traceId;
            }
        }@catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    });
}
#pragma mark - RUM
// rum:start resource
- (void)interceptTask:(NSURLSessionTask *)task{
    BOOL isWebSocketHandshake = task.ft_isWebSocketTask;
    uint64_t startTime = isWebSocketHandshake ? [FTDateUtil continuousTime] : 0;
    long long startNsTimeInterval = isWebSocketHandshake ? [[NSDate date] ft_nanosecondTimeStamp] : 0;
    FTURLSessionRequestSnapshot *requestSnapshot = [FTURLSessionRequestSnapshot snapshotWithRequest:task.currentRequest];
    NSURL *resourceURL = isWebSocketHandshake ? task.ft_webSocketResourceURL : requestSnapshot.URL;
    dispatch_async(self.queue, ^{
        @try {
            FTSessionTaskHandler *handler = [self getTraceHandler:task];
            if(!requestSnapshot || !resourceURL || ![self isTraceUrl:resourceURL]){
                if(handler)[self removeTraceHandlerWithKey:task];
                return;
            }
            if(!handler){
                handler = [[FTSessionTaskHandler alloc]init];
                [self setTraceHandler:handler forKey:task];
            }
            if (isWebSocketHandshake && handler.webSocketHandshakeStarted) {
                return;
            }
            handler.requestSnapshot = requestSnapshot;
            if (isWebSocketHandshake) {
                handler.webSocketHandshake = YES;
                handler.webSocketHandshakeStartTime = startTime;
                handler.webSocketHandshakeStartNsTimeInterval = startNsTimeInterval;
                handler.webSocketURL = resourceURL;
                NSMutableURLRequest *webSocketRequest = [requestSnapshot.request mutableCopy];
                webSocketRequest.URL = resourceURL;
                handler.request = [webSocketRequest copy];
                handler.webSocketHandshakeStarted = YES;
            }
            [self startResourceWithKey:handler.identifier];
        }@catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    });
}
/// rum: addResource
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics{
    [self taskMetricsCollected:task metrics:metrics custom:YES];
}
-(void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics custom:(BOOL)custom{
    [self taskMetricsCollected:task metrics:metrics custom:custom extraProvider:nil];
}
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics custom:(BOOL)custom extraProvider:(nullable ResourcePropertyProvider)extraProvider{
    uint64_t endTime = [FTDateUtil continuousTime];
    NSURLResponse *completedResponse = task.response;
    NSError *completedError = task.error;
    NSURLSessionTaskState taskState = task.state;
    ResourcePropertyProvider webSocketProvider = extraProvider ?: self.resourcePropertyProvider;
    BOOL hasCompletion = task.ft_hasCompletion;
    dispatch_async(self.queue, ^{
        @try {
            FTSessionTaskHandler *handler = [self getTraceHandler:task];
            if(!handler){
                return;
            }
            [handler taskReceivedMetrics:metrics custom:custom];
            if (handler.webSocketHandshake) {
                // Automatic collection uses didOpen for success and completion for failure.
                // Metrics only supplies timing data on that path.
                if (!custom) {
                    return;
                }
                NSInteger status = [completedResponse isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)completedResponse).statusCode : 0;
                // Existing public forwarding has no required open callback, so retain its
                // metrics compatibility path. A 101 alone is insufficient: validation can fail.
                BOOL successfulResponse = status == 101 || (status >= 200 && status < 300);
                if (taskState == NSURLSessionTaskStateRunning && !completedError && successfulResponse) {
                    [self completeWebSocketHandshakeForTask:task
                                                   handler:handler
                                                  response:completedResponse
                                                    error:nil
                                                    state:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS
                                                  endTime:endTime
                                            extraProvider:webSocketProvider
                                               errorFilter:nil];
                }
                // Failures retain the completion path and its task-specific error filter.
                return;
            }
            if(!custom){
                if (@available(iOS 15.0,tvOS 15.0,macOS 12.0, *)) {
                    //macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *
                    if(!hasCompletion){
                        ResourcePropertyProvider provider = self.resourcePropertyProvider;
                        SessionTaskErrorFilter filter = self.sessionTaskErrorFilter;
                        [self handleTaskCompleted:task response:completedResponse error:completedError extraProvider:provider errorFilter:filter endTime:endTime];
                    }
                }
            }
        }@catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    });
}
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data{
    dispatch_async(self.queue, ^{
        @try {
            FTSessionTaskHandler *handler = [self getTraceHandler:task];
            if(!handler){
                return;
            }
            // Use the response when available so incremental body buffering can skip media before completion.
            handler.response = task.response;
            [handler taskReceivedData:data];
        }@catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    });
}
- (void)taskReceivedCompleteData:(NSURLSessionTask *)task data:(NSData *)data{
    dispatch_async(self.queue, ^{
        @try {
            FTSessionTaskHandler *handler = [self getTraceHandler:task];
            if(!handler){
                return;
            }
            handler.response = task.response;
            [handler taskReceivedCompleteData:data];
        }@catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    });
}
/// WebSocket open is the successful handshake boundary. It must not wait for later connection close.
- (void)taskWebSocketDidOpen:(NSURLSessionTask *)task extraProvider:(nullable ResourcePropertyProvider)extraProvider{
    uint64_t endTime = [FTDateUtil continuousTime];
    ResourcePropertyProvider provider = extraProvider?:self.resourcePropertyProvider;
    NSURLResponse *response = task.response;
    dispatch_async(self.queue, ^{
        @try {
            FTSessionTaskHandler *handler = [self getTraceHandler:task];
            if (!handler || !handler.webSocketHandshake) {
                return;
            }
            [self completeWebSocketHandshakeForTask:task
                                            handler:handler
                                           response:response
                                             error:nil
                                             state:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS
                                           endTime:endTime
                                     extraProvider:provider
                                        errorFilter:nil];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    });
}
/// rum: stopResource
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error{
    [self taskCompleted:task error:error extraProvider:nil errorFilter:nil];
}
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider{
    [self taskCompleted:task error:error extraProvider:extraProvider errorFilter:nil];
}
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider errorFilter:(nullable SessionTaskErrorFilter)errorFilter{
    uint64_t endTime = [FTDateUtil continuousTime];
    ResourcePropertyProvider provider = extraProvider?:self.resourcePropertyProvider;
    SessionTaskErrorFilter filter = errorFilter?:self.sessionTaskErrorFilter;
    NSURLResponse *completedResponse = task.response;
    dispatch_async(self.queue, ^{
        @try {
            [self handleTaskCompleted:task response:completedResponse error:error extraProvider:provider errorFilter:filter endTime:endTime];
        }@catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    });
}

- (void)handleTaskCompleted:(NSURLSessionTask *)task response:(NSURLResponse *)response error:(NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider errorFilter:(nullable SessionTaskErrorFilter)errorFilter endTime:(uint64_t)endTime{
    FTSessionTaskHandler *handler = [self getTraceHandler:task];
    if(!handler){
        return;
    }
    if (handler.webSocketHandshake) {
        NSString *state = [self webSocketHandshakeStateWithResponse:response];
        [self completeWebSocketHandshakeForTask:task
                                        handler:handler
                                       response:response
                                         error:error
                                         state:state
                                       endTime:endTime
                                 extraProvider:extraProvider
                                    errorFilter:errorFilter];
        return;
    }
    BOOL filterError = NO;
    if (errorFilter && error) {
        filterError = errorFilter(error);
    }
    [handler taskCompletedWithResponse:response error:filterError?nil:error];
    [self removeTraceHandlerWithKey:task];
    NSDictionary *property;
    if(extraProvider){
        property = extraProvider(handler.request, handler.response, handler.data, handler.error);
        property = [property ft_deepCopy];
    }
    [self stopResourceWithKey:handler.identifier property:property];
    __block NSString *span_id = handler.spanID,*trace_id=handler.traceID;
    if (self.tracer.enableLinkRumData&&span_id==nil&&trace_id==nil) {
        [self.tracer unpackTraceHeader:handler.requestSnapshot.allHTTPHeaderFields handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            span_id = spanID;
            trace_id = traceId;
        }];
    }
    [self addResourceWithKey:handler.identifier metrics:handler.metricsModel content:handler.contentModel spanID:span_id traceID:trace_id];
}

- (NSString *)webSocketHandshakeStateWithResponse:(nullable NSURLResponse *)response{
    if ([response isKindOfClass:NSHTTPURLResponse.class] && ((NSHTTPURLResponse *)response).statusCode != 101) {
        return FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_REJECTED;
    }
    return FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_FAILED;
}

- (void)completeWebSocketHandshakeForTask:(NSURLSessionTask *)task
                                  handler:(FTSessionTaskHandler *)handler
                                 response:(nullable NSURLResponse *)response
                                   error:(nullable NSError *)error
                                   state:(NSString *)state
                                 endTime:(uint64_t)endTime
                           extraProvider:(nullable ResourcePropertyProvider)extraProvider
                              errorFilter:(nullable SessionTaskErrorFilter)errorFilter{
    // Prefer Foundation's opening-handshake task interval, preserving phase offsets.
    // Only synthesize an interval when metrics are missing or have no valid duration.
    FTResourceMetricsModel *metrics = handler.metricsModel ?: [FTResourceMetricsModel new];
    if (!metrics.fetchInterval) {
        metrics.fetchStartNsTimeInterval = handler.webSocketHandshakeStartNsTimeInterval;
        metrics.fetchEndNsTimeInterval = metrics.fetchStartNsTimeInterval + (long long)(endTime - handler.webSocketHandshakeStartTime);
    }
    handler.metricsModel = metrics;
    BOOL filterError = errorFilter && error ? errorFilter(error) : NO;
    NSError *contentError = filterError ? nil : error;
    [handler taskCompletedWithResponse:response error:contentError];

    FTResourceContentModel *content = handler.contentModel;
    content.webSocketHandshake = YES;
    content.webSocketHandshakeState = state;
    content.resourceType = FT_RESOURCE_TYPE_WEBSOCKET;
    content.url = handler.webSocketURL ?: handler.request.URL;
    content.httpMethod = @"GET";
    if ([state isEqualToString:FT_RESOURCE_WEBSOCKET_HANDSHAKE_STATE_SUCCESS]) {
        if (content.httpStatusCode < 0) {
            content.httpStatusCode = 101;
        }
    } else if (content.httpStatusCode < 0) {
        content.httpStatusCode = 0;
    }

    [self removeTraceHandlerWithKey:task];
    NSDictionary *property;
    if(extraProvider){
        property = extraProvider(handler.request, handler.response, nil, handler.error);
        property = [property ft_deepCopy];
    }
    [self stopResourceWithKey:handler.identifier property:property];
    __block NSString *span_id = handler.spanID,*trace_id=handler.traceID;
    if (self.tracer.enableLinkRumData&&span_id==nil&&trace_id==nil) {
        [self.tracer unpackTraceHeader:handler.requestSnapshot.allHTTPHeaderFields handler:^(NSString * _Nullable traceId, NSString * _Nullable spanID) {
            span_id = spanID;
            trace_id = traceId;
        }];
    }
    [self addResourceWithKey:handler.identifier metrics:handler.metricsModel content:content spanID:span_id traceID:trace_id];
}

#pragma mark --------- external data ----------
-(NSDictionary *)getTraceHeaderWithUrl:(NSURL *)url{
    if(!_tracer){
        FTInnerLogError(@"SDK configuration Trace error, trace is not supported");
        return nil;
    }
    return [self.tracer networkTraceHeaderWithUrl:url];
}
// `SkyWalking` requires URL parameter
-(NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    if(!_tracer){
        FTInnerLogError(@"SDK configuration Trace error, trace is not supported");
        return nil;
    }
    NSDictionary *dict = nil;
    if(self.tracer.enableLinkRumData){
        __block FTSessionTaskHandler *handler = [[FTSessionTaskHandler alloc]initWithIdentifier:key];
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
    if (self.rumResourceHandler && [self.rumResourceHandler respondsToSelector:@selector(startResourceWithKey:)]) {
        [self.rumResourceHandler startResourceWithKey:key];
    }
}
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property{
    if (self.rumResourceHandler && [self.rumResourceHandler respondsToSelector:@selector(startResourceWithKey:property:)]) {
        [self.rumResourceHandler startResourceWithKey:key property:property];
    }
}
- (void)stopResourceWithKey:(nonnull NSString *)key{
    if (self.rumResourceHandler && [self.rumResourceHandler respondsToSelector:@selector(stopResourceWithKey:)]) {
        [self.rumResourceHandler stopResourceWithKey:key];
    }
}
-(void)stopResourceWithKey:(NSString *)key property:(NSDictionary *)property{
    if (self.rumResourceHandler && [self.rumResourceHandler respondsToSelector:@selector(stopResourceWithKey:property:)]) {
        [self.rumResourceHandler stopResourceWithKey:key property:property];
    }
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content{
    FTSessionTaskHandler *handler = [self getTraceHandler:key];
    [self addResourceWithKey:key metrics:metrics content:content spanID:handler.spanID traceID:handler.traceID];
}
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID{
    [self removeTraceHandlerWithKey:key];
    if (self.rumResourceHandler && [self.rumResourceHandler respondsToSelector:@selector(addResourceWithKey:metrics:content:spanID:traceID:)]) {
        [self.rumResourceHandler addResourceWithKey:key metrics:metrics content:content spanID:spanID traceID:traceID];
    }
}
- (void)shutDown{
    if(dispatch_get_specific(FTInterceptorQueueIdentityKey)==NULL){
        dispatch_sync(self.queue, ^{});
    }
    @synchronized(sharedInstanceLock) {
        sharedInstance =nil;
    }    
}
@end
