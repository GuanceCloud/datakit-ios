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
#import "NSURLRequest+FTMonitor.h"
#import "FTResourceContentModel.h"
#import "FTTraceHandler.h"
#import "FTNetworkTrace.h"
#import "FTMonitorManager.h"
#import "FTRUMManager.h"
#import "FTBaseInfoHandler.h"
#import "FTResourceMetricsModel.h"
#import "FTConfigManager.h"
static NSString *const URLProtocolHandledKey = @"URLProtocolHandledKey";//为了避免死循环

@interface FTURLProtocol ()<NSURLSessionDelegate,NSURLSessionTaskDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSOperationQueue* sessionDelegateQueue;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics API_AVAILABLE(ios(10.0));

@property (nonatomic, assign) BOOL trackUrl;
@property (nonatomic, strong) FTTraceHandler *traceHandler;
@property (nonatomic, copy) NSString *identifier;
@end
@implementation FTURLProtocol
//static id<FTHTTPProtocolDelegate> sDelegate;

// 开始监听
+ (void)startMonitor {
    FTSessionConfiguration *sessionConfiguration = [FTSessionConfiguration defaultConfiguration];
    [NSURLProtocol registerClass:[FTURLProtocol class]];
    if (![sessionConfiguration isExchanged]) {
        [sessionConfiguration load];
    }
}

// 停止监听
+ (void)stopMonitor {
    FTSessionConfiguration *sessionConfiguration = [FTSessionConfiguration defaultConfiguration];
    [NSURLProtocol unregisterClass:[FTURLProtocol class]];
    if ([sessionConfiguration isExchanged]) {
        [sessionConfiguration unload];
    }
}
//+ (id<FTHTTPProtocolDelegate>)delegate
//{
//    id<FTHTTPProtocolDelegate> result;
//    
//    @synchronized (self) {
//        result = sDelegate;
//    }
//    return result;
//}
//+ (void)setDelegate:(id)newValue{
//    @synchronized (self) {
//        sDelegate = newValue;
//    }
//}
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    
    NSString * scheme = [[request.URL scheme] lowercaseString];
    
    //看看是否已经处理过了，防止无限循环 根据业务来截取
    if ([NSURLProtocol propertyForKey: URLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    
    if ([scheme isEqualToString:@"http"] ||
        [scheme isEqualToString:@"https"]) {
        return YES;
    }
    
    return NO;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return [request ft_NetworkTrace];
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client {
    return [super initWithRequest:request cachedResponse:cachedResponse client:client];
}

//开始请求
- (void)startLoading
{
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    self.trackUrl = [[FTNetworkTrace sharedInstance] isTraceUrl:mutableReqeust.URL];
    //标示该request已经处理过了，防止无限循环
    [NSURLProtocol setProperty:@(YES) forKey:URLProtocolHandledKey inRequest:mutableReqeust];
    
    
    //使用NSURLSession继续把request发送出去
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.sessionDelegateQueue                             = [[NSOperationQueue alloc] init];
    self.sessionDelegateQueue.maxConcurrentOperationCount = 1;
    self.sessionDelegateQueue.name                        = @"com.session.queue";
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:self.sessionDelegateQueue];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:mutableReqeust];
    if (self.trackUrl) {
        self.identifier = [NSUUID UUID].UUIDString;
        if([FTNetworkTrace sharedInstance].enableAutoTrace){
        self.traceHandler = [[FTTraceHandler alloc]initWithUrl:mutableReqeust.URL identifier:self.identifier];
        self.traceHandler.requestHeader = mutableReqeust.allHTTPHeaderFields;
        }
        if ([FTConfigManager sharedInstance].rumConfig.enableTraceUserResource) {
            [[FTMonitorManager sharedInstance].rumManger startResource:self.identifier];
        }
    }
    [task resume];
}

//结束请求
- (void)stopLoading {
    [self.session invalidateAndCancel];
    self.session = nil;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if (self.trackUrl) {
        self.data = data;
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
    if (self.trackUrl) {
        NSDate *start = nil;
        NSNumber *duration = @(-1);
        if (@available(iOS 11.0, *)) {
            if (self.metrics) {
                NSURLSessionTaskTransactionMetrics *taskMes = [self.metrics.transactionMetrics lastObject];
                start = taskMes.requestStartDate;
                duration = [NSNumber numberWithInt:[self.metrics.taskInterval duration]*1000000];
            }
        }
        FTResourceContentModel *model = [FTResourceContentModel new];
        model.url = self.request.URL;
        model.requestHeader = self.request.allHTTPHeaderFields;
        model.httpMethod = self.request.HTTPMethod;
        NSHTTPURLResponse *response =(NSHTTPURLResponse *)task.response;
        if (response) {
            NSDictionary *responseHeader = response.allHeaderFields;
            model.responseHeader = responseHeader;
            model.httpStatusCode = response.statusCode;
            if (self.data) {
                model.responseBody = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
            }
        }
        model.error = error;
        model.duration = duration;
        if([FTNetworkTrace sharedInstance].enableAutoTrace){
            [self.traceHandler tracingWithModel:model];
        }
        if (![FTConfigManager sharedInstance].rumConfig.enableTraceUserResource) {
            return;
        }
        FTResourceMetricsModel *metricsModel = nil;
        if (@available(iOS 10.0, *)) {
            if (self.metrics) {
                metricsModel = [[FTResourceMetricsModel alloc]initWithTaskMetrics:self.metrics];
            }
        }
        [[FTMonitorManager sharedInstance].rumManger stopResource:self.identifier];

        [[FTMonitorManager sharedInstance].rumManger addResource:self.identifier metrics:metricsModel content:model spanID:self.traceHandler.getSpanID traceID:self.traceHandler.getTraceID];
    }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics  API_AVAILABLE(ios(10.0)){
    
    if (self.trackUrl ) {
        self.metrics = metrics;
    }
    
}

@end
