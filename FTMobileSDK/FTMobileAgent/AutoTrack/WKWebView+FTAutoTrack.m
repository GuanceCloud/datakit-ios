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
#import "FTSwizzler.h"
#import <objc/runtime.h>
#import "NSObject+FTAutoTrack.h"
static void Hook_Method(Class originalClass, SEL originalSel, Class replacedClass, SEL replacedSel, SEL noneSel){
    // 原实例方法
    Method originalMethod = class_getInstanceMethod(originalClass, originalSel);
    // 替换的实例方法
    Method replacedMethod = class_getInstanceMethod(replacedClass, replacedSel);
    
    
    // 如果没有实现 delegate 方法，则手动动态添加
    if (!originalMethod) {
        Method noneMethod = class_getInstanceMethod(replacedClass, noneSel);
        class_addMethod(originalClass, originalSel, method_getImplementation(noneMethod), method_getTypeEncoding(noneMethod));
    }
    originalMethod = class_getInstanceMethod(originalClass, originalSel);
    // 向实现 delegate 的类中添加新的方法
    // 这里是向 originalClass 的 replaceSel（@selector(owner_webViewDidStartLoad:)） 添加 replaceMethod
    BOOL didAddMethod = class_addMethod(originalClass, replacedSel, method_getImplementation(replacedMethod), method_getTypeEncoding(replacedMethod));
    if (didAddMethod) {
        // 添加成功
        // 重新拿到添加被添加的 method,这里是关键(注意这里 originalClass, 不 replacedClass), 因为替换的方法已经添加到原类中了, 应该交换原类中的两个方法
        Method newMethod = class_getInstanceMethod(originalClass, replacedSel);
        // 实现交换
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

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
    if (navigationDelegate != nil) {
       Class realClass = [FTSwizzler realDelegateClassFromSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:) proxy:navigationDelegate];
        // request
       Hook_Method(realClass, @selector(webView:decidePolicyForNavigationAction:decisionHandler:), [self class], @selector(dataflux_webView:decidePolicyForNavigationAction:decisionHandler:), @selector(dataflux_none_webView:decidePolicyForNavigationAction:decisionHandler:));
       //response
       Hook_Method(realClass, @selector(webView:decidePolicyForNavigationResponse:decisionHandler:), [self class], @selector(dataflux_webView:decidePolicyForNavigationResponse:decisionHandler:), @selector(dataflux_none_webView:decidePolicyForNavigationResponse:decisionHandler:));
       //load error
       Hook_Method(realClass, @selector(webView:didFailProvisionalNavigation:withError:), [self class], @selector(dataflux_webView:didFailProvisionalNavigation:withError:), @selector(dataflux_none_webView:didFailProvisionalNavigation:withError:));
       //webView:didCommitNavigation:
       Hook_Method(realClass, @selector(webView:didCommitNavigation:), [self class], @selector(dataflux_webView:didCommitNavigation:), @selector(dataflux_none_webView:didCommitNavigation:));
       //navigation Finish
       Hook_Method(realClass, @selector(webView:didFinishNavigation:), [self class], @selector(dataflux_webView:didFinishNavigation:), @selector(dataflux_none_webView:didFinishNavigation:));
       }
    [self dataflux_setNavigationDelegate:navigationDelegate];
}
-(void)dataflux_dealloc{
    [[FTWKWebViewHandler sharedInstance] removeWebView:self];
    [self dataflux_dealloc];
}

// request
-(void)dataflux_webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] addRequest:navigationAction.request webView:webView];
    }
    //允许跳转
    decisionHandler(WKNavigationActionPolicyAllow);
}
//response
-(void)dataflux_webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] addResponse:navigationResponse.response webView:webView];
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}
//load error
-(void)dataflux_webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] didRequestFailWithError:error webView:webView];
    }
}
//webView:didCommitNavigation:
-(void)dataflux_webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] loadingWebView:webView];
    }
}
//navigation Finish
-(void)dataflux_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] didFinishWithWebview:webView];
    }
}
// request
-(void)dataflux_none_webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{                                                                                                                                          decisionHandler(WKNavigationActionPolicyAllow);
}
//response
-(void)dataflux_none_webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    
    decisionHandler(WKNavigationResponsePolicyAllow);
}
//load error
-(void)dataflux_none_webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    
}
//webView:didCommitNavigation:
-(void)dataflux_none_webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    
}
//navigation Finish
-(void)dataflux_none_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    
}
@end

