//
//  FTWKWebViewHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTWKWebViewHandler.h"
#import "ZYAspects.h"
#import "NSURLRequest+FTMonitor.h"
#import "FTLog.h"
@interface FTWKWebViewHandler ()
@property (nonatomic, strong) NSMutableDictionary *mutableRequestKeyedByWebviewHash;
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
        self.mutableRequestKeyedByWebviewHash = [NSMutableDictionary new];
        self.mutableLoadStateByWebviewHash = [NSMutableDictionary new];
        self.lock = [NSLock new];
        self.trace = NO;
    }
    return self;
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
    [self.lock lock];
    if ([self.mutableLoadStateByWebviewHash.allKeys containsObject:key] && [[self.mutableLoadStateByWebviewHash valueForKey:key] isEqual:@NO]) {
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
        if([request.URL isEqual:response.URL] && [[self.mutableLoadStateByWebviewHash valueForKey:key] isEqual:@NO]){
            [self.mutableLoadStateByWebviewHash setValue:@YES forKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
            isTrace = YES;
        }
    }
    [self.lock unlock];
    if (isTrace) {
        NSNumber  *duration = [NSNumber numberWithDouble:[endDate timeIntervalSinceDate:request.ftRequestStartDate]*1000*1000];
        if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewTraceRequest:response:startDate:taskDuration:)]) {
            [self.traceDelegate ftWKWebViewTraceRequest:request response:response startDate:request.ftRequestStartDate taskDuration:duration];
        }
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
- (BOOL)needTraceReloadWebView:(WKWebView *)webView{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    BOOL need = NO;
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebviewHash.allKeys containsObject:key]) {
        NSURLRequest *request = [self.mutableRequestKeyedByWebviewHash objectForKey:key];
        if ([request.URL isEqual:webView.URL] && !webView.canGoBack) {
            need = YES;
        }
    }
    [self.lock unlock];
    return need;
}
- (void)addWebView:(WKWebView *)webView completionHandler:(void (^)(NSURLRequest *request,BOOL needTrace))completionHandler{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    NSURLRequest *request;
       [self.lock lock];
       if ([self.mutableRequestKeyedByWebviewHash.allKeys containsObject:key]) {
        request = [self.mutableRequestKeyedByWebviewHash objectForKey:key];
       }
       [self.lock unlock];
    if ([request.URL isEqual:webView.URL] && !webView.canGoBack) {
        completionHandler? completionHandler(request,YES):nil;
    }else{
        completionHandler? completionHandler(nil,NO):nil;
    }
}
 
@end
