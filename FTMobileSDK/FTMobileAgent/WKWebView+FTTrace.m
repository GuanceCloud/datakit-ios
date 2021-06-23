//
//  WKWebView+FTHook.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/15.
//  Copyright © 2020 hll. All rights reserved.
//

#import "WKWebView+FTTrace.h"
#import "FTLog.h"
#import "FTWKWebViewHandler.h"
#import <objc/runtime.h>
#import "FTMonitorManager.h"
#import "NSURLRequest+FTMonitor.h"
@implementation WKWebView (FTTrace)
static void Hook_Method(Class originalClass, SEL originalSel, Class replacedClass, SEL replacedSel, SEL noneSel){
    // 原实例方法
    Method originalMethod = class_getInstanceMethod(originalClass, originalSel);
    // 替换的实例方法
    Method replacedMethod = class_getInstanceMethod(replacedClass, replacedSel);
    
    
    // 如果没有实现 delegate 方法，则手动动态添加
    if (!originalMethod) {
        Method noneMethod = class_getInstanceMethod(replacedClass, noneSel);
        BOOL didAddNoneMethod = class_addMethod(originalClass, originalSel, method_getImplementation(noneMethod), method_getTypeEncoding(noneMethod));
        if (didAddNoneMethod) {
            ZYDebug(@"******** 没有实现 (%@) 方法，手动添加成功！！",NSStringFromSelector(originalSel));
        }
    }
    originalMethod = class_getInstanceMethod(originalClass, originalSel);
    // 向实现 delegate 的类中添加新的方法
    // 这里是向 originalClass 的 replaceSel（@selector(owner_webViewDidStartLoad:)） 添加 replaceMethod
    BOOL didAddMethod = class_addMethod(originalClass, replacedSel, method_getImplementation(replacedMethod), method_getTypeEncoding(replacedMethod));
    if (didAddMethod) {
        // 添加成功
        ZYDebug(@"******** 实现了 (%@) 方法并成功 Hook 为 --> (%@)",NSStringFromSelector(originalSel) ,NSStringFromSelector(replacedSel));
        // 重新拿到添加被添加的 method,这里是关键(注意这里 originalClass, 不 replacedClass), 因为替换的方法已经添加到原类中了, 应该交换原类中的两个方法
        Method newMethod = class_getInstanceMethod(originalClass, replacedSel);
        // 实现交换
        method_exchangeImplementations(originalMethod, newMethod);
    }else{
        // 添加失败，则说明已经 hook 过该类的 delegate 方法，防止多次交换。
        ZYDebug(@"******** 已替换过，避免多次替换 --> (%@)",NSStringFromClass(originalClass));
    }
}
///动态交换方法
static void Exchange_Method(Class cls, SEL method1, SEL method2){
    Method m1 = class_getInstanceMethod(cls, method1);
    Method m2 = class_getInstanceMethod(cls, method2);
    method_exchangeImplementations(m1, m2);
}
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL oriMethod =  NSSelectorFromString(@"dealloc");
        Class class = [WKWebView class];
        //dealloc
        Exchange_Method(class,oriMethod,@selector(fthook_dealloc));

        //setNavigationDelegate:
        Exchange_Method(class,@selector(setNavigationDelegate:),@selector(fthook_setNavigationDelegate:));
        //reload
        Exchange_Method(class,@selector(reload),@selector(fthook_reload));

        //loadRequest:
        Exchange_Method(class,@selector(loadRequest:),@selector(fthook_loadRequest:));

        //loadHTMLString
        Exchange_Method(class,@selector(loadHTMLString:baseURL:),@selector(fthook_loadHTMLString:baseURL:));

        //loadFileURL
        Exchange_Method(class,@selector(loadFileURL:allowingReadAccessToURL:),@selector(fthook_loadFileURL:allowingReadAccessToURL:));
    });
}
- (WKNavigation *)fthook_loadRequest:(NSURLRequest *)request{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    if ([FTWKWebViewHandler sharedInstance].trace) {
        NSURLRequest *newrequest = [request ft_NetworkTrace];
        if (!self.navigationDelegate) {
            self.navigationDelegate = [FTWKWebViewHandler sharedInstance];
        }
        [[FTWKWebViewHandler sharedInstance] addWebView:self];
        return  [self fthook_loadRequest:newrequest];
    }else{
        return [self fthook_loadRequest:request];
    }
}
- (WKNavigation *)fthook_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self fthook_loadHTMLString:string baseURL:baseURL];
}
- (WKNavigation *)fthook_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self fthook_loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}
- (WKNavigation *)fthook_reload{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        dispatch_semaphore_t signal = dispatch_semaphore_create(1);
        __block BOOL trace = NO;
        __block NSURLRequest *newRequest = nil;
        [[FTWKWebViewHandler sharedInstance] reloadWebView:self completionHandler:^(NSURLRequest * _Nonnull request, BOOL needTrace) {
            dispatch_semaphore_signal(signal);
            if (needTrace && request) {
                trace = YES;
                newRequest = request;
            }
        }];
        dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
        return  trace?[self loadRequest:newRequest]:[self fthook_reload];
    }else{
        return [self fthook_reload];
    }
}
- (void)fthook_dealloc{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        [[FTWKWebViewHandler sharedInstance] removeWebView:self];
    }
    [self fthook_dealloc];
}
- (void)fthook_setNavigationDelegate:(id<WKNavigationDelegate>)delegate {
    if (delegate != nil) {
    // request
    Hook_Method([delegate class], @selector(webView:decidePolicyForNavigationAction:decisionHandler:), [self class], @selector(owner_webView:decidePolicyForNavigationAction:decisionHandler:), @selector(none_webView:decidePolicyForNavigationAction:decisionHandler:));
    //response
    Hook_Method([delegate class], @selector(webView:decidePolicyForNavigationResponse:decisionHandler:), [self class], @selector(owner_webView:decidePolicyForNavigationResponse:decisionHandler:), @selector(none_webView:decidePolicyForNavigationResponse:decisionHandler:));
    //load error
    Hook_Method([delegate class], @selector(webView:didFailProvisionalNavigation:withError:), [self class], @selector(owner_webView:didFailProvisionalNavigation:withError:), @selector(none_webView:didFailProvisionalNavigation:withError:));
    //webView:didCommitNavigation:
    Hook_Method([delegate class], @selector(webView:didCommitNavigation:), [self class], @selector(owner_webView:didCommitNavigation:), @selector(none_webView:didCommitNavigation:));
    //navigation Finish
    Hook_Method([delegate class], @selector(webView:didFinishNavigation:), [self class], @selector(owner_webView:didFinishNavigation:), @selector(none_webView:didFinishNavigation:));
    }
    [self fthook_setNavigationDelegate:delegate];
    
}
- (void)owner_webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        [[FTWKWebViewHandler sharedInstance] addRequest:navigationAction.request webView:webView];
    }
    //允许跳转
    [self owner_webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    
}
- (void)none_webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    //允许跳转
    decisionHandler(WKNavigationActionPolicyAllow);
}
- (void)owner_webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        [[FTWKWebViewHandler sharedInstance] addResponse:navigationResponse.response webView:webView];
    }
    [self owner_webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:decisionHandler];
}
- (void)none_webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    decisionHandler(WKNavigationResponsePolicyAllow);
}
- (void)owner_webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        [[FTWKWebViewHandler sharedInstance] didRequestFailWithError:error webView:webView];
    }
    [self owner_webView:webView didFailProvisionalNavigation:navigation withError:error];
}
- (void)none_webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error{
}
- (void)owner_webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        [[FTWKWebViewHandler sharedInstance] loadingWebView:webView];
    }
}
- (void)none_webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation{
}
- (void)none_webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation{

}
- (void)owner_webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        [[FTWKWebViewHandler sharedInstance] didFinishWithWebview:webView];
    }
    [self owner_webView:webView didFinishNavigation:navigation];
}
@end
