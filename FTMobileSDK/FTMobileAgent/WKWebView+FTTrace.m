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

    Method originalNoneMethod = class_getInstanceMethod(replacedClass, noneSel);

    // 如果没有实现 delegate 方法，则手动动态添加
    if (!originalMethod) {
        Method noneMethod = class_getInstanceMethod(replacedClass, noneSel);
        BOOL didAddNoneMethod = class_addMethod(originalClass, originalSel, method_getImplementation(noneMethod), method_getTypeEncoding(noneMethod));
        if (didAddNoneMethod) {
            ZYDebug(@"******** 没有实现 (%@) 方法，手动添加成功！！",NSStringFromSelector(originalSel));
        }
        return;
    }
    if (originalNoneMethod) {
        return;
    }
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

+ (void)load {
    SEL oriMethod =  NSSelectorFromString(@"dealloc");


    Method originalLoadMethod = class_getInstanceMethod([WKWebView class], oriMethod);
    Method ownerLoadMethod = class_getInstanceMethod([WKWebView class], @selector(fthook_dealloc));
    method_exchangeImplementations(originalLoadMethod, ownerLoadMethod);

    // Hook UIWebView
    Method originalMethod = class_getInstanceMethod([WKWebView class], @selector(setNavigationDelegate:));
    Method ownerMethod = class_getInstanceMethod([WKWebView class], @selector(fthook_setNavigationDelegate:));
    method_exchangeImplementations(originalMethod, ownerMethod);
    
    Method originalreLoadMethod = class_getInstanceMethod([WKWebView class], @selector(reload));
      Method ownerreLoadMethod = class_getInstanceMethod([WKWebView class], @selector(fthook_reload));
      method_exchangeImplementations(originalreLoadMethod, ownerreLoadMethod);
}
- (void)ft_loadRequest:(NSURLRequest *)request{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        NSURLRequest *newrequest = [request ft_NetworkTrace];
        if (!self.navigationDelegate) {
            self.navigationDelegate = [FTWKWebViewHandler sharedInstance];
        }
        [[FTWKWebViewHandler sharedInstance] addWebView:self];
        [self loadRequest:newrequest];
    }else{
        [self loadRequest:request];
    }
}
- (void)fthook_reload{
    if ([FTWKWebViewHandler sharedInstance].trace) {
        [[FTWKWebViewHandler sharedInstance] addWebView:self completionHandler:^(NSURLRequest * _Nonnull request, BOOL needTrace) {
            if (needTrace && request) {
                [self ft_loadRequest:request];
            }else{
                [self fthook_reload];
            }
        }];
    }else{
        [self fthook_reload];
    }
}
- (void)fthook_dealloc{
     if ([FTWKWebViewHandler sharedInstance].trace) {
    [[FTWKWebViewHandler sharedInstance] removeWebView:self];
     }
    [self fthook_dealloc];
}
- (void)fthook_setNavigationDelegate:(id<UIWebViewDelegate>)delegate {
    
    Hook_Method([delegate class], @selector(webView:decidePolicyForNavigationAction:decisionHandler:), [self class], @selector(owner_webView:decidePolicyForNavigationAction:decisionHandler:), @selector(none_webView:decidePolicyForNavigationAction:decisionHandler:));
    Hook_Method([delegate class], @selector(webView:decidePolicyForNavigationResponse:decisionHandler:), [self class], @selector(owner_webView:decidePolicyForNavigationResponse:decisionHandler:), @selector(none_webView:decidePolicyForNavigationResponse:decisionHandler:));
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
    if ([FTWKWebViewHandler sharedInstance].trace) {
    [[FTWKWebViewHandler sharedInstance] addRequest:navigationAction.request webView:webView];
    }
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
    if ([FTWKWebViewHandler sharedInstance].trace) {
    [[FTWKWebViewHandler sharedInstance] addResponse:navigationResponse.response webView:webView];
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

@end
