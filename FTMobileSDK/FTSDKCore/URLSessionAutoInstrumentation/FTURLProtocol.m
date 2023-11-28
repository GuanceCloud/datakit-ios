//
//  FTURLProtocol.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTURLProtocol.h"
#import "FTSessionConfiguration.h"
static NSString *const URLProtocolHandledKey = @"FTURLProtocolHandledKey";//为了避免死循环

@interface FTURLProtocol ()<NSURLSessionDelegate,NSURLSessionDataDelegate>
@property (atomic, strong, readwrite) NSURLSessionDataTask *task;
@end
@implementation FTURLProtocol
static id<FTAutoInterceptorProtocol> sDelegate;

+ (id<FTAutoInterceptorProtocol>)delegate{
    id<FTAutoInterceptorProtocol> result;
    @synchronized (self) {
        result = sDelegate;
    }
    return result;
}
+ (void)setDelegate:(id<FTAutoInterceptorProtocol>)delegate{
    @synchronized (self) {
        sDelegate = delegate;
    }
}
+ (BOOL)canInitWithTask:(NSURLSessionTask *)task {
    NSURLRequest *request = task.currentRequest;
    return request == nil ? NO : [self canInitWithRequest:request];
}
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    
    NSString * scheme = [[request.URL scheme] lowercaseString];
    
    //看看是否已经处理过了，防止无限循环 根据业务来截取
    if ([NSURLProtocol propertyForKey: URLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    if (![FTSessionConfiguration defaultConfiguration].shouldIntercept) {
        return NO;
    }
    if ([scheme isEqualToString:@"http"] ||
        [scheme isEqualToString:@"https"]) {
        NSString *contentType = [request valueForHTTPHeaderField:@"Content-Type"];
        if (contentType && [contentType containsString:@"multipart/form-data"]) {
            return NO;
        }
        id<FTAutoInterceptorProtocol> strongeDelegate;
        strongeDelegate = [[self class] delegate];
        if ([strongeDelegate respondsToSelector:@selector(isTraceUrl:)]) {
            return  [strongeDelegate isTraceUrl:request.URL];
        }
        return YES;
    }
    
    return NO;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    //标示该request已经处理过了，防止无限循环
    [NSURLProtocol setProperty:@(YES) forKey:URLProtocolHandledKey inRequest:mutableReqeust];
    id<FTAutoInterceptorProtocol> strongeDelegate;
    strongeDelegate = [[self class] delegate];
    if (strongeDelegate.interceptor && [strongeDelegate.interceptor respondsToSelector:@selector(interceptRequest:)]) {
        return [strongeDelegate.interceptor interceptRequest:mutableReqeust];
    }
    return mutableReqeust;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client {
    return [super initWithRequest:request cachedResponse:cachedResponse client:client];
}

//开始请求
- (void)startLoading{
    NSMutableArray *        calculatedModes;
    NSString *              currentMode;
    calculatedModes = [NSMutableArray array];
    [calculatedModes addObject:NSDefaultRunLoopMode];
    currentMode = [[NSRunLoop currentRunLoop] currentMode];
    if ( (currentMode != nil) && ! [currentMode isEqual:NSDefaultRunLoopMode] ) {
        [calculatedModes addObject:currentMode];
    }
    self.task = [[FTSessionConfiguration defaultConfiguration] dataTaskWithRequest:self.request delegate:self modes:calculatedModes];
    id<FTAutoInterceptorProtocol> strongeDelegate;
    strongeDelegate = [[self class] delegate];
    if (strongeDelegate && strongeDelegate.enableAutoRumTrack && strongeDelegate.interceptor && [strongeDelegate.interceptor respondsToSelector:@selector(interceptTask:)]) {
        [strongeDelegate.interceptor interceptTask:self.task];
    }
    [self.task resume];
}
//结束请求
- (void)stopLoading {
    if (self.task != nil) {
        [self.task cancel];
        self.task = nil;
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    id<FTAutoInterceptorProtocol> strongeDelegate;
    strongeDelegate = [[self class] delegate];
    if (strongeDelegate && strongeDelegate.enableAutoRumTrack && strongeDelegate.interceptor &&[strongeDelegate.interceptor respondsToSelector:@selector(taskReceivedData:data:)]) {
        [strongeDelegate.interceptor taskReceivedData:dataTask data:data];
    }
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
    id<FTAutoInterceptorProtocol> strongeDelegate;
    strongeDelegate = [[self class] delegate];
    if (strongeDelegate && strongeDelegate.enableAutoRumTrack && strongeDelegate.interceptor && [strongeDelegate.interceptor respondsToSelector:@selector(taskCompleted:error:)]) {
        [strongeDelegate.interceptor taskCompleted:task error:error];
    }
    
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics  API_AVAILABLE(ios(10.0)){
    id<FTAutoInterceptorProtocol> strongeDelegate;
    strongeDelegate = [[self class] delegate];
    if (strongeDelegate && strongeDelegate.enableAutoRumTrack && strongeDelegate.interceptor && [strongeDelegate.interceptor respondsToSelector:@selector(taskMetricsCollected:metrics:)]) {
        [strongeDelegate.interceptor taskMetricsCollected:task metrics:metrics];
    };
}

@end
