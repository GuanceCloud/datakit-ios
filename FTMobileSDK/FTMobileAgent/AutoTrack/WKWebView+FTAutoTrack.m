//
//  WKWebView+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewHandler.h"
#import "NSURLRequest+FTMonitor.h"
@implementation WKWebView (FTAutoTrack)

-(WKNavigation *)dataflux_loadRequest:(NSURLRequest *)request{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        NSURLRequest *newrequest = [request ft_NetworkTrace];
        if (!self.navigationDelegate) {
            self.navigationDelegate = [FTWKWebViewHandler sharedInstance];
        }
        [[FTWKWebViewHandler sharedInstance] addWebView:self];
        return  [self dataflux_loadRequest:newrequest];
    }else{
        return [self dataflux_loadRequest:request];
    }
}

-(WKNavigation *)dataflux_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self dataflux_loadHTMLString:string baseURL:baseURL];
}

-(WKNavigation *)dataflux_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self dataflux_loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}
-(WKNavigation *)dataflux_reload{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        __block BOOL trace = NO;
        __block NSURLRequest *newRequest = nil;
        [[FTWKWebViewHandler sharedInstance] reloadWebView:self completionHandler:^(NSURLRequest * _Nonnull request, BOOL needTrace) {
            if (needTrace && request) {
                trace = YES;
                newRequest = request;
            }
        }];
        return  trace?[self loadRequest:newRequest]:[self dataflux_reload];
    }else{
        return [self dataflux_reload];
    }
}
-(void)dataflux_setNavigationDelegate:(id<WKNavigationDelegate>)navigationDelegate{
    
}
-(void)dataflux_dealloc{
    [[FTWKWebViewHandler sharedInstance] removeWebView:self];
    [self dataflux_dealloc];
}

@end

@interface FTWKWebViewDelegate : NSObject<WKNavigationDelegate>

@end
@implementation FTWKWebViewDelegate
// request
-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] addRequest:navigationAction.request webView:webView];
    }
    //允许跳转
    decisionHandler(WKNavigationActionPolicyAllow);
}
//response
-(void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] addResponse:navigationResponse.response webView:webView];
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}
//load error
-(void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] didRequestFailWithError:error webView:webView];
    }
}
//webView:didCommitNavigation:
-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] loadingWebView:webView];
    }
}
//navigation Finish
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] didFinishWithWebview:webView];
    }
}
@end
