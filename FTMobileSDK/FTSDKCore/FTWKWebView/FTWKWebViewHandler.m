//
//  FTWKWebViewHandler.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "FTWKWebViewHandler.h"
#import "FTWKWebViewHandler+Private.h"
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTLog+Private.h"
#import "FTReadWriteHelper.h"
#import <os/lock.h>

@interface FTWKWebViewHandler ()
@property (nonatomic, weak) id<FTWKWebViewRumDelegate> rumTrackDelegate;
@property (nonatomic, copy) NSString *allowWebViewHostsString;
@property (nonatomic, strong) NSHashTable *allWebViews;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, assign) BOOL enableTraceWebView;
@end
@implementation FTWKWebViewHandler
static FTWKWebViewHandler *sharedInstance = nil;
static NSObject *sharedInstanceLock;
+ (void)initialize{
    if (self == [FTWKWebViewHandler class]) {
        sharedInstanceLock = [[NSObject alloc] init];
    }
}
+ (instancetype)sharedInstance {
    @synchronized(sharedInstanceLock) {
        if (!sharedInstance) {
            sharedInstance = [[self alloc] init];
        }
        return sharedInstance;
    }
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.allWebViews = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
        self.lock = [[NSRecursiveLock alloc] init];
        self.enableTraceWebView = NO;
    }
    return self;
}
- (void)startWithEnableTraceWebView:(BOOL)enable allowWebViewHost:(NSArray *)hosts rumDelegate:(id<FTWKWebViewRumDelegate>)delegate{
    _enableTraceWebView = enable;
    if (enable) {
        [self setWKWebViewTrace];
    }
    self.allowWebViewHostsString = [self transHostsArrayToString:hosts];
    self.rumTrackDelegate = delegate;
}
- (void)setWKWebViewTrace{
    static dispatch_once_t onceTokenWebView;
    dispatch_once(&onceTokenWebView, ^{
        NSError *error = NULL;
        [WKWebView ft_swizzleMethod:@selector(loadRequest:)
                         withMethod:@selector(ft_loadRequest:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadHTMLString:baseURL:)
                         withMethod:@selector(ft_loadHTMLString:baseURL:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadFileURL:allowingReadAccessToURL:)
                         withMethod:@selector(ft_loadFileURL:allowingReadAccessToURL:)
                              error:&error];
        SEL deallocMethod =  NSSelectorFromString(@"dealloc");
        [WKWebView ft_swizzleMethod:deallocMethod
                         withMethod:@selector(ft_dealloc)
                              error:&error];
    });
}
#pragma mark request
- (void)setBridge:(FTWKWebViewJavascriptBridge *)bridge forWebView:(WKWebView *)webView{
    if (!webView || !bridge) return;
    [self.lock lock];
    @try {
        webView.ft_jsBridge = bridge;
        [self.allWebViews addObject:webView];
    } @finally {
        [self.lock unlock];
    }
}
- (void)addWebView:(WKWebView *)webView{
    [self.lock lock];
    [self.allWebViews addObject:webView];
    [self.lock unlock];
}
- (void)removeBridgeForWebView:(WKWebView *)webView{
    if (!webView) return;
    [self.lock lock];
    @try {
        FTWKWebViewJavascriptBridge *bridge = webView.ft_jsBridge;
        [bridge removeScriptMessageHandler];
        webView.ft_jsBridge = nil;
        [self.allWebViews removeObject:webView];
    } @finally {
        [self.lock unlock];
    }
}
- (void)removeAllWebViewBridges{
    [self.lock lock];
    @try {
        NSArray<WKWebView *> *webViewSnapshot = [self.allWebViews allObjects];
        for (WKWebView *webView in webViewSnapshot) {
            [self removeBridgeForWebView:webView];
        }
    } @finally {
        [self.lock unlock];
    }
}
- (NSString *)transHostsArrayToString:(NSArray *)hosts{
    @try {
        if(hosts && hosts.count>0){
            NSArray *hostsCopy = [hosts copy];
            NSMutableArray<NSString *> *quotedHosts = [[NSMutableArray alloc] initWithCapacity:hostsCopy.count];
            [hostsCopy enumerateObjectsUsingBlock:^(NSString * _Nonnull host, NSUInteger idx, BOOL * _Nonnull stop) {
                [quotedHosts addObject:[NSString stringWithFormat:@"\\\"%@\\\"", host]];
            }];
            return  [NSString stringWithFormat:@"\"[%@]\"",[quotedHosts componentsJoinedByString:@","]];
        }else{
            return @"null";
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    return @"null";
}
- (void)innerEnableWebView:(WKWebView *)webView{
    if (self.enableTraceWebView) {
        [self _enableWebView:webView allowedWebViewHostsString:self.allowWebViewHostsString];
    }
}
- (void)enableWebView:(WKWebView *)webView{
    [self _enableWebView:webView allowedWebViewHostsString:self.allowWebViewHostsString];
}
- (void)enableWebView:(WKWebView *)webView allowWebViewHost:(NSArray *)hosts{
    NSString *allowedHosts = [self transHostsArrayToString:hosts];
    [self _enableWebView:webView allowedWebViewHostsString:allowedHosts];
}
- (void)_enableWebView:(WKWebView *)webView allowedWebViewHostsString:(NSString *)hostsString{
    @try {
        if (webView.ft_jsBridge) {
            FTInnerLogDebug(@"WebView(%@) already add JSBridge.",webView);
            return;
        }
        FTWKWebViewJavascriptBridge *bridge = [FTWKWebViewJavascriptBridge bridgeForWebView:webView allowWebViewHostsString:hostsString];
        __weak typeof(self) weakSelf = self;
        [bridge registerHandler:@"sendEvent" handler:^(id data, int64_t slotId,WVJBResponseCallback responseCallback) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            id<FTWKWebViewRumDelegate> delegate = strongSelf.rumTrackDelegate;
            if (delegate && [delegate respondsToSelector:@selector(dealReceiveScriptMessage:slotId:)]){
                [delegate dealReceiveScriptMessage:data slotId:slotId];
            }
        }];
        [self setBridge:bridge forWebView:webView];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
- (void)disableWebView:(WKWebView *)webView{
    @try {
        [self removeBridgeForWebView:webView];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
+ (void)shutDown{
    @synchronized(sharedInstanceLock) {
        [sharedInstance removeAllWebViewBridges];
        sharedInstance = nil;
    }
}
@end

#endif
