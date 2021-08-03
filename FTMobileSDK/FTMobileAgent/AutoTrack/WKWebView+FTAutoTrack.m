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
static void dataflux_addInstanceMethod(SEL selector,SEL addSelector,Class fromClass, Class toClass) {
    NSCParameterAssert(fromClass);
    NSCParameterAssert(toClass);
    Method originalMethod = class_getInstanceMethod(toClass, selector);
    if(!originalMethod){
    Method method = class_getInstanceMethod(fromClass, addSelector);
    // 返回该方法的实现
    IMP methodIMP = method_getImplementation(method);
    // 获取该方法的返回类型
    const char *types = method_getTypeEncoding(method);
    // 在 toClass 中，添加方法
        class_addMethod(toClass, selector, methodIMP, types);
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
        SEL requestM = @selector(webView:decidePolicyForNavigationAction:decisionHandler:);
        SEL responseM = @selector(webView:decidePolicyForNavigationResponse:decisionHandler:);
        SEL loadErrorM = @selector(webView:didFailProvisionalNavigation:withError:);
        SEL webViewCommitM = @selector(webView:didCommitNavigation:);
        SEL navigationFinishM = @selector(webView:didFinishNavigation:);
        
        if(!realClass.dataFlux_className){
            realClass.dataFlux_className = NSStringFromClass(realClass);
            if(![FTSwizzler realDelegateClass:realClass respondsToSelector:requestM]){
                dataflux_addInstanceMethod(requestM,@selector(dataflux_none_webView:decidePolicyForNavigationAction:decisionHandler:), WKWebView.class, realClass);
            }
            if(![FTSwizzler realDelegateClass:realClass respondsToSelector:responseM]){
                dataflux_addInstanceMethod(responseM,@selector(dataflux_none_webView:decidePolicyForNavigationResponse:decisionHandler:), WKWebView.class, realClass);
            }
            if(![FTSwizzler realDelegateClass:realClass respondsToSelector:loadErrorM]){
                dataflux_addInstanceMethod(loadErrorM,@selector(dataflux_none_webView:didFailProvisionalNavigation:withError:), WKWebView.class, realClass);
            }
            if(![FTSwizzler realDelegateClass:realClass respondsToSelector:webViewCommitM]){
                dataflux_addInstanceMethod(webViewCommitM,@selector(dataflux_none_webView:didCommitNavigation:), WKWebView.class, realClass);
            }
            if(![FTSwizzler realDelegateClass:realClass respondsToSelector:navigationFinishM]){
                dataflux_addInstanceMethod(navigationFinishM,@selector(dataflux_none_webView:didFinishNavigation:), WKWebView.class, realClass);
            }
            [FTSwizzler swizzleSelector:requestM onClass:realClass withBlock:^(id instance, SEL method, WKWebView *webView, WKNavigationAction *navigationAction,id decisionHandler) {
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] addRequest:navigationAction.request webView:webView];
                }
                
            
            } named:@"dataflux_wkwebview_request"];

            [FTSwizzler swizzleSelector:responseM onClass:realClass withBlock:^(id instance, SEL method, WKWebView *webView, WKNavigationResponse *navigationResponse,id decisionHandler) {
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] addResponse:navigationResponse.response webView:webView];
                }
            
            } named:@"dataflux_wkwebview_response"];
            [FTSwizzler swizzleSelector:loadErrorM onClass:realClass withBlock:^(id instance, SEL method, WKWebView *webView, WKNavigation *navigation,NSError *error) {
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] didRequestFailWithError:error webView:webView];
                }
            
            } named:@"dataflux_wkwebview_loadError"];
            [FTSwizzler swizzleSelector:webViewCommitM onClass:realClass withBlock:^(id instance, SEL method, WKWebView *webView, WKNavigation *navigation) {
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] loadingWebView:webView];
                }
            
            } named:@"dataflux_wkwebview_webViewCommit"];
            [FTSwizzler swizzleSelector:navigationFinishM onClass:realClass withBlock:^(id instance, SEL method, WKWebView *webView, WKNavigation *navigation) {
                if ([FTWKWebViewHandler sharedInstance].enableTrace) {
                    [[FTWKWebViewHandler sharedInstance] didFinishWithWebview:webView];
                }
            } named:@"dataflux_wkwebview_navigationFinish"];
        }
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

