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
#import "FTInternalLog.h"
#import "FTDateUtil.h"
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
@interface FTWKWebViewHandler ()
@property (nonatomic, strong) NSMutableDictionary *mutableRequestKeyedByWebviewHash;

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
        SEL deallocMethod =  NSSelectorFromString(@"dealloc");
        [WKWebView ft_swizzleMethod:deallocMethod
                         withMethod:@selector(dataflux_dealloc)
                              error:&error];
    });
}
#pragma mark request
- (void)addWebView:(WKWebView *)webView request:(NSURLRequest *)request{
    [self.lock lock];
    if (![self.mutableRequestKeyedByWebviewHash.allKeys containsObject:[[NSNumber numberWithInteger:webView.hash] stringValue]]) {
        [self.mutableRequestKeyedByWebviewHash setValue:request forKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
    }
    [self.lock unlock];
}
- (void)removeWebView:(WKWebView *)webView{
    [self.lock lock];
    if ([self.mutableRequestKeyedByWebviewHash.allKeys containsObject:[[NSNumber numberWithInteger:webView.hash] stringValue]]) {
        [self.mutableRequestKeyedByWebviewHash removeObjectForKey:[[NSNumber numberWithInteger:webView.hash] stringValue]];
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
    if (request && [request.URL isEqual:webView.URL]) {
        completionHandler? completionHandler(request,YES):nil;
    }else{
        completionHandler? completionHandler(nil,NO):nil;
    }
}
- (void)addScriptMessageHandlerWithWebView:(WKWebView *)webView{
    if (self.rumTrackDelegate && [self.rumTrackDelegate respondsToSelector:@selector(ftAddScriptMessageHandlerWithWebView:)]) {
        [self.rumTrackDelegate ftAddScriptMessageHandlerWithWebView:webView];
    }
}
@end

