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
@property (nonatomic, strong) NSMutableDictionary *mutableRequestKeyedByWebview;
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
        self.mutableRequestKeyedByWebview = [NSMutableDictionary new];
        self.lock = [NSLock new];
    }
    return self;
}
#pragma mark request
- (void)addWebView:(WKWebView *)webView{
    [self.lock lock];
    if (![self.mutableRequestKeyedByWebview.allKeys containsObject:[[NSNumber numberWithInteger:webView.hash] stringValue]]) {
    [self.mutableRequestKeyedByWebview setValue:@NO forKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
    }
    [self.lock unlock];
}
- (void)addRequest:(NSURLRequest *)request webView:(WKWebView *)webView{
    NSString *key = [[NSNumber numberWithInteger:webView.hash] stringValue];
    request.ftRequestStartDate = [NSDate date];
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebview.allKeys containsObject:key]) {
        id data = [self.mutableRequestKeyedByWebview valueForKey:key];
        if ([data isEqual:@NO]) {
        [self.mutableRequestKeyedByWebview setValue:request forKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
        }
    }
    [self.lock unlock];
}
- (void)addResponse:(NSURLResponse *)response webView:(WKWebView *)webView{
    NSDate *endDate = [NSDate date];
    NSURLRequest *request;
    [self.lock lock];
    id data = [self.mutableRequestKeyedByWebview objectForKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
    if ([data isKindOfClass:NSURLRequest.class]) {
        request = data;
        if([request.URL isEqual:response.URL]){
            [self.mutableRequestKeyedByWebview setValue:@YES forKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
        }
    }
    [self.lock unlock];
    if (request) {
        NSNumber  *duration = [NSNumber numberWithDouble:[endDate timeIntervalSinceDate:request.ftRequestStartDate]*1000*1000];
        if (self.traceDelegate && [self.traceDelegate respondsToSelector:@selector(ftWKWebViewTraceRequest:response:startDate:taskDuration:)]) {
            [self.traceDelegate ftWKWebViewTraceRequest:request response:response startDate:request.ftRequestStartDate taskDuration:duration];
        }
    }
   
}

- (void)removeWebView:(WKWebView *)webView{
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebview.allKeys containsObject:[[NSNumber numberWithInteger:webView.hash] stringValue]]) {
        [self.mutableRequestKeyedByWebview removeObjectForKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
    }
    [self.lock unlock];
}
 
@end
