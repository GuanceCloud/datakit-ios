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
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTLog+Private.h"

@interface FTWKWebViewHandler ()
@property (nonatomic, strong) NSMapTable *webViewRequestTable;
@property (nonatomic, strong) NSMapTable *webViewBridge;

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
        self.webViewRequestTable = [NSMapTable weakToStrongObjectsMapTable];
        self.webViewBridge = [NSMapTable weakToStrongObjectsMapTable];
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
                         withMethod:@selector(ft_loadRequest:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadHTMLString:baseURL:)
                         withMethod:@selector(ft_loadHTMLString:baseURL:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadFileURL:allowingReadAccessToURL:)
                         withMethod:@selector(ft_loadFileURL:allowingReadAccessToURL:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(reload) withMethod:@selector(ft_reload) error:&error];
    });
}
#pragma mark request
- (void)addWebView:(WKWebView *)webView request:(NSURLRequest *)request{
    [self.lock lock];
    [self.webViewRequestTable setObject:request forKey:webView];
    [self.lock unlock];
}
- (void)reloadWebView:(WKWebView *)webView completionHandler:(void (^)(NSURLRequest *request,BOOL needTrace))completionHandler{
    NSURLRequest *request;
    [self.lock lock];
    request = [self.webViewRequestTable objectForKey:webView];
    [self.lock unlock];
    if (request && [request.URL isEqual:webView.URL]) {
        completionHandler? completionHandler(request,YES):nil;
    }else{
        completionHandler? completionHandler(nil,NO):nil;
    }
}
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
- (void)addScriptMessageHandlerWithWebView:(WKWebView *)webView{
    if (self.rumTrackDelegate && [self.rumTrackDelegate respondsToSelector:@selector(dealReceiveScriptMessage:slotId:viewId:)]) {
           if ([self getWebViewBridge:webView]) {
               FTInnerLogDebug(@"WebView(%@) already add JSBridge.",webView);
               return;
           }
           FTWKWebViewJavascriptBridge *bridge = [FTWKWebViewJavascriptBridge bridgeForWebView:webView];
           __weak typeof(self) weakSelf = self;
           [bridge registerHandler:@"sendEvent" handler:^(id data, int64_t slotId,WVJBResponseCallback responseCallback) {
               __strong __typeof(weakSelf) strongSelf = weakSelf;
               if (!strongSelf) {
                   return;
               }
               if (bridge.viewID == nil) {
                   bridge.viewID = [strongSelf.rumTrackDelegate getLastViewID];
               }
               [strongSelf.rumTrackDelegate dealReceiveScriptMessage:data slotId:slotId viewId:bridge.viewID];
           }];
           [self addWebView:webView bridge:bridge];
       }
}
@end

#endif
