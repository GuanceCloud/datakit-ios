//
//  FTWKWebViewHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTWKWebViewHandler.h"
#import "NSURLRequest+FTMonitor.h"
#import "FTLog.h"
#import "NSDate+FTAdd.h"
#import "WKWebView+FTAutoTrack.h"
#import "NSURLResponse+FTMonitor.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTMobileAgent+Private.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
@interface FTWKWebViewHandler ()
@property (nonatomic, strong) NSMutableDictionary *mutableRequestKeyedByWebviewHash;
//记录trace wkwebview的request url trace状态 为YES时，trace完成
@property (nonatomic, strong) NSMutableDictionary *mutableLoadStateByWebviewHash;

@property (nonatomic, strong) NSLock *lock;
@end
@implementation FTWKWebViewHandler
static FTWKWebViewHandler *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        [self setWKWebViewTrace];
        self.mutableRequestKeyedByWebviewHash = [NSMutableDictionary new];
        self.mutableLoadStateByWebviewHash = [NSMutableDictionary new];
        self.lock = [NSLock new];
        self.enableTrace = NO;
    }
    return self;
}
- (void)setWKWebViewTrace{
    static dispatch_once_t onceTokenWebView;
    dispatch_once(&onceTokenWebView, ^{
        NSError *error = NULL;
        
        [WKWebView ft_swizzleMethod:@selector(loadRequest:)
                         withMethod:@selector(dataflux_loadRequest:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadHTMLString:baseURL:)
                         withMethod:@selector(dataflux_loadHTMLString:baseURL:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadFileURL:allowingReadAccessToURL:)
                         withMethod:@selector(dataflux_loadFileURL:allowingReadAccessToURL:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(reload) withMethod:@selector(dataflux_reload) error:&error];
        [WKWebView ft_swizzleMethod:@selector(setNavigationDelegate:) withMethod:@selector(dataflux_setNavigationDelegate:) error:&error];
        
        SEL deallocMethod =  NSSelectorFromString(@"dealloc");
        [WKWebView ft_swizzleMethod:deallocMethod
                         withMethod:@selector(dataflux_dealloc)
                              error:&error];
    });
}
#pragma mark request
- (void)addWebView:(WKWebView *)webView{
    [self.lock lock];
    [self.mutableLoadStateByWebviewHash setValue:@NO forKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
    [self.lock unlock];
}
- (void)addRequest:(NSURLRequest *)request webView:(WKWebView *)webView{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    request.ftRequestStartDate = [NSDate date];
    ZYDebug(@"%@",request.ftRequestStartDate);
    [self.lock lock];
    if ([self.mutableLoadStateByWebviewHash.allKeys containsObject:key]) {
        [self.mutableRequestKeyedByWebviewHash setValue:request forKey:key];
    }
    [self.lock unlock];
}
- (void)addResponse:(NSURLResponse *)response webView:(WKWebView *)webView{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    NSDate *endDate = [NSDate date];
    BOOL isTrace = NO;
    [self.lock lock];
    NSURLRequest *request = [self.mutableRequestKeyedByWebviewHash objectForKey:key];
    if (request) {
        if([[self.mutableLoadStateByWebviewHash valueForKey:key] isEqual:@NO] && [request.URL isEqual:response.URL]){
            [self.mutableLoadStateByWebviewHash setValue:@YES forKey:key];
            isTrace = YES;
        }
    }
    [self.lock unlock];
    // 判断是否是SDK添加链路追踪信息的request
    // wkwebview 使用loadRequest 与 reload 发起的请求
    if (isTrace) {
        NSNumber  *duration = [endDate ft_microcrosecondtimeIntervalSinceDate:request.ftRequestStartDate];
        if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewTraceRequest:response:startDate:taskDuration:error:)]) {
            [self.traceDelegate ftWKWebViewTraceRequest:request response:response startDate:request.ftRequestStartDate taskDuration:duration error:nil];
        }
    }
    if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewTraceRequest:isError:)]) {
        BOOL iserror = [[response ft_getResponseStatusCode] integerValue] >=400? YES:NO;
        [self.traceDelegate ftWKWebViewTraceRequest:request isError:iserror];
    }
}

- (void)removeWebView:(WKWebView *)webView{
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebviewHash.allKeys containsObject:[[NSNumber numberWithInteger:webView.hash] stringValue]]) {
        [self.mutableRequestKeyedByWebviewHash removeObjectForKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
        [self.mutableLoadStateByWebviewHash removeObjectForKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
        
    }
    [self.lock unlock];
}
- (void)reloadWebView:(WKWebView *)webView completionHandler:(void (^)(NSURLRequest *request,BOOL needTrace))completionHandler{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    NSURLRequest *request;
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebviewHash.allKeys containsObject:key]) {
        request = [self.mutableRequestKeyedByWebviewHash objectForKey:key];
    }
    [self.lock unlock];
    if ([request.URL isEqual:webView.URL]) {
        [self addWebView:webView];
        completionHandler? completionHandler(request,YES):nil;
    }else{
        completionHandler? completionHandler(nil,NO):nil;
    }
}
- (void)loadingWebView:(WKWebView *)webView{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    NSDate *endDate = [NSDate date];
    NSURLRequest *request;
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebviewHash.allKeys containsObject:key]) {
        request = [self.mutableRequestKeyedByWebviewHash objectForKey:key];
    }
    [self.lock unlock];
    if ([request.URL isEqual:webView.URL]) {
        NSNumber  *duration = [endDate ft_nanotimeIntervalSinceDate:request.ftRequestStartDate];
        if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewLoadingWithURL:duration:)]) {
            [self.traceDelegate ftWKWebViewLoadingWithURL:webView.URL duration:duration];
        }
    }
}
-(void)didFinishWithWebview:(WKWebView *)webView{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    NSDate *endDate = [NSDate date];
    NSURLRequest *request;
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebviewHash.allKeys containsObject:key]) {
        request = [self.mutableRequestKeyedByWebviewHash objectForKey:key];
    }
    [self.lock unlock];
    if ([request.URL isEqual:webView.URL]) {
        NSNumber  *duration = [endDate ft_nanotimeIntervalSinceDate:request.ftRequestStartDate];
        if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewLoadCompletedWithURL:duration:)]) {
            [self.traceDelegate ftWKWebViewLoadCompletedWithURL:webView.URL duration:duration];
        }
    }
}
- (void)didRequestFailWithError:(NSError *)error webView:(WKWebView *)webview{
    NSString *key = [[NSNumber numberWithInteger:webview.hash] stringValue];
    NSDate *endDate = [NSDate date];
    BOOL isTrace = NO;
    [self.lock lock];
    NSURLRequest *request = [self.mutableRequestKeyedByWebviewHash objectForKey:key];
    if (request) {
        if([[self.mutableLoadStateByWebviewHash valueForKey:key] isEqual:@NO] && [request.URL isEqual:webview.URL]){
            [self.mutableLoadStateByWebviewHash setValue:@YES forKey:key];
            isTrace = YES;
        }
    }
    [self.lock unlock];
    if (isTrace) {
        NSNumber  *duration = [endDate ft_nanotimeIntervalSinceDate:request.ftRequestStartDate];
        if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewTraceRequest:response:startDate:taskDuration:error:)]) {
            [self.traceDelegate ftWKWebViewTraceRequest:request response:nil startDate:request.ftRequestStartDate taskDuration:duration error:error];
        }
    }
    if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewTraceRequest:isError:)]) {
        [self.traceDelegate ftWKWebViewTraceRequest:request isError:YES];
    }
}
#pragma mark -
- (void)addScriptMessageHandlerWithWebView:(WKWebView *)webView{
    if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftAddScriptMessageHandlerWithWebView:)]) {
        [self.traceDelegate ftAddScriptMessageHandlerWithWebView:webView];
    }
}
@end
@implementation FTWKWebViewHandler (HookDelegate)

@end
