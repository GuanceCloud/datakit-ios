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
static void dataflux_addInstanceMethod(SEL selector,Class fromClass, Class toClass) {
    NSCParameterAssert(fromClass);
    NSCParameterAssert(toClass);
    Method method = class_getInstanceMethod(fromClass, selector);
    // 返回该方法的实现
    IMP methodIMP = method_getImplementation(method);
    // 获取该方法的返回类型
    const char *types = method_getTypeEncoding(method);
    // 在 toClass 中，添加方法
    if (!class_addMethod(toClass, selector, methodIMP, types)) {
        class_replaceMethod(toClass, selector, methodIMP, types);
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
    [self dataflux_setNavigationDelegate:navigationDelegate];
    if([navigationDelegate isKindOfClass:FTWKWebViewHandler.class]){
        return;
    }
    SEL webViewRequest = @selector(webView:decidePolicyForNavigationAction:decisionHandler:);
    SEL webViewResponse = @selector(webView:decidePolicyForNavigationResponse:decisionHandler:);
    SEL webViewLoadError = @selector(webView:didFailProvisionalNavigation:withError:);
    SEL loadingWebView = @selector(webView:didCommitNavigation:);
    SEL navigationFinish = @selector(webView:didFinishNavigation:);
    
    Class class = [FTSwizzler realDelegateClassFromSelector:webViewRequest proxy:navigationDelegate];
    if(!class.dataFlux_className){
    [class setDataFlux_className:NSStringFromClass(class)];
    if (![FTSwizzler realDelegateClass:class respondsToSelector:webViewRequest]) {
        dataflux_addInstanceMethod(webViewRequest,FTWKWebViewHandler.class,class);
    }else{
        [FTSwizzler swizzleInstanceMethod:webViewRequest inClass:FTWKWebViewHandler.class newImpFactory:^id(FTSwizzleInfo *swizzleInfo) {
            void (*originalImplementation_)(__unsafe_unretained id,SEL,id,id,id);
            SEL selector_ = swizzleInfo.selector;
            return ^void(__unsafe_unretained id instance,WKWebView * webView,WKNavigationAction * navigationAction,id decisionHandler){

                ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(instance, selector_,webView,navigationAction,decisionHandler);
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] addRequest:navigationAction.request webView:webView];
                }
            };
        }];
    }
    if (![FTSwizzler realDelegateClass:class respondsToSelector:webViewResponse]) {
        dataflux_addInstanceMethod(webViewResponse,FTWKWebViewHandler.class,class);
    }else{
        [FTSwizzler swizzleInstanceMethod:webViewResponse inClass:FTWKWebViewHandler.class newImpFactory:^id(FTSwizzleInfo *swizzleInfo) {
            void (*originalImplementation_)(__unsafe_unretained id,SEL,id,id,id);
            SEL selector_ = swizzleInfo.selector;
            return ^void(__unsafe_unretained id instance,WKWebView * webView,WKNavigationResponse * navigationResponse,id decisionHandler){

                ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(instance, selector_,webView,navigationResponse,decisionHandler);
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] addResponse:navigationResponse.response webView:webView];
                }
            };
        }];
    }
    if (![FTSwizzler realDelegateClass:class respondsToSelector:webViewLoadError]) {
        dataflux_addInstanceMethod(webViewLoadError,FTWKWebViewHandler.class,class);
    }else{
        [FTSwizzler swizzleInstanceMethod:webViewLoadError inClass:FTWKWebViewHandler.class newImpFactory:^id(FTSwizzleInfo *swizzleInfo) {
            void (*originalImplementation_)(__unsafe_unretained id,SEL,id,id,id);
            SEL selector_ = swizzleInfo.selector;
            return ^void(__unsafe_unretained id instance,WKWebView * webView,WKNavigation * navigation,NSError * error){

                ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(instance, selector_,webView,navigation,error);
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] didRequestFailWithError:error webView:webView];
                }
            };
        }];
    }
    if (![FTSwizzler realDelegateClass:class respondsToSelector:loadingWebView]) {
        dataflux_addInstanceMethod(loadingWebView,FTWKWebViewHandler.class,class);
    }else{
        [FTSwizzler swizzleInstanceMethod:loadingWebView inClass:FTWKWebViewHandler.class newImpFactory:^id(FTSwizzleInfo *swizzleInfo) {
            void (*originalImplementation_)(__unsafe_unretained id,SEL,id,id);
            SEL selector_ = swizzleInfo.selector;
            return ^void(__unsafe_unretained id instance,WKWebView * webView,WKNavigation * navigation){

                ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(instance, selector_,webView,navigation);
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] loadingWebView:webView];
                }
            };
        }];
    }
    if (![FTSwizzler realDelegateClass:class respondsToSelector:navigationFinish]) {
        dataflux_addInstanceMethod(navigationFinish,FTWKWebViewHandler.class,class);
    }else{
        [FTSwizzler swizzleInstanceMethod:navigationFinish inClass:FTWKWebViewHandler.class newImpFactory:^id(FTSwizzleInfo *swizzleInfo) {
            void (*originalImplementation_)(__unsafe_unretained id,SEL,id,id);
            SEL selector_ = swizzleInfo.selector;
            return ^void(__unsafe_unretained id instance,WKWebView * webView,WKNavigation * navigation){

                ((__typeof(originalImplementation_))[swizzleInfo getOriginalImplementation])(instance, selector_,webView,navigation);
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] didFinishWithWebview:webView];
                }
            };
        }];
    }
    }
}
-(void)dataflux_dealloc{
    [[FTWKWebViewHandler sharedInstance] removeWebView:self];
    [self dataflux_dealloc];
}

@end

