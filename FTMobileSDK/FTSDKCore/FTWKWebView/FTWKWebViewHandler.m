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
#import "FTWKWebViewHandler+Private.h"
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTLog+Private.h"
#import "FTReadWriteHelper.h"

@interface FTWKWebViewHandler ()
@property (nonatomic, weak) id<FTWKWebViewRumDelegate> rumTrackDelegate;
@property (nonatomic, strong) NSMapTable *webViewBridge;
@property (nonatomic, copy) NSString *allowWebViewHostsString;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL enableTraceWebView;
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
        self.webViewBridge = [NSMapTable weakToStrongObjectsMapTable];
        self.lock = [NSLock new];
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
    });
}
#pragma mark request
- (void)addWebView:(WKWebView *)webView bridge:(id)bridge{
    [self.lock lock];
    [self.webViewBridge setObject:bridge forKey:webView];
    [self.lock unlock];
}
- (id)getWebViewBridge:(WKWebView *)webView{
    id bridge = nil;
    [self.lock lock];
    bridge = [self.webViewBridge objectForKey:webView];
    [self.lock unlock];
    return bridge;
}
- (void)removeWebViewBridge:(WKWebView *)webView{
    [self.lock lock];
    [self.webViewBridge removeObjectForKey:webView];
    [self.lock unlock];
}
- (void)removeAllWebViewBridges{
    [self.lock lock];
    NSEnumerator *enumerator = self.webViewBridge.objectEnumerator;
    FTWKWebViewJavascriptBridge *bridge;
    while ((bridge = [enumerator nextObject])) {
        [bridge removeScriptMessageHandler];
    }
    [self.lock unlock];
}
- (NSString *)transHostsArrayToString:(NSArray *)hosts{
    if(hosts && hosts.count>0){
        NSArray *hostsCopy = [hosts copy];
        NSMutableArray<NSString *> *quotedHosts = [[NSMutableArray alloc] initWithCapacity:hostsCopy.count];
        [hostsCopy enumerateObjectsUsingBlock:^(NSString * _Nonnull host, NSUInteger idx, BOOL * _Nonnull stop) {
            [quotedHosts addObject:[NSString stringWithFormat:@"\\\"%@\\\"", host]];
        }];
        return  [quotedHosts componentsJoinedByString:@","];
    }
    return @"";
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
    if ([self getWebViewBridge:webView]) {
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
        if (strongSelf.rumTrackDelegate && [strongSelf.rumTrackDelegate respondsToSelector:@selector(dealReceiveScriptMessage:slotId:)]){
            [strongSelf.rumTrackDelegate dealReceiveScriptMessage:data slotId:slotId];
        }
    }];
    [self addWebView:webView bridge:bridge];
}
- (void)disableWebView:(WKWebView *)webView{
    FTWKWebViewJavascriptBridge *bridge = [self getWebViewBridge:webView];
    [bridge removeScriptMessageHandler];
    [self removeWebViewBridge:webView];
}
- (void)shutDown{
    [self removeAllWebViewBridges];
    onceToken = 0;
    sharedInstance = nil;
}
@end

#endif
