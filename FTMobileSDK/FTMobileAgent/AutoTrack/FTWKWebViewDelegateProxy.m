//
//  FTWKWebViewDelegateProxy.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/20.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTWKWebViewDelegateProxy.h"
#import <WebKit/WKWebView.h>
#import "FTLog.h"
#import "NSObject+FTAutoTrack.h"
#import "FTWKWebViewHandler.h"
#import "FTSwizzler.h"
//#import "SAClassHelper.h"
//#import "SAMethodHelper.h"
#import <objc/message.h>
@implementation FTWKWebViewDelegateProxy
+ (void)proxyWithDelegate:(id)delegate {
    @try {
        [FTWKWebViewDelegateProxy hookWKNavigationDelegatetMethodWithDelegate:delegate];
    } @catch (NSException *exception) {
        ZYErrorLog(@"exception: %@", self, exception);
    }
}

+ (void)hookWKNavigationDelegatetMethodWithDelegate:(id)delegate {
    // 当前代理对象已经处理过,避免重复
    if ([delegate dataFlux_className]) {
        return;
    }
    
    SEL webViewRequest = @selector(webView:decidePolicyForNavigationAction:decisionHandler:);
    SEL webViewResponse = @selector(webView:decidePolicyForNavigationResponse:decisionHandler:);
    SEL webViewLoadError = @selector(webView:didFailProvisionalNavigation:withError:);
    SEL  loadingWebView= @selector(webView:didCommitNavigation:);
    SEL navigationFinish= @selector(webView:didFinishNavigation:);
    

    Class proxyClass = [FTWKWebViewDelegateProxy class];
    
    Class statedClass = [delegate class];
    Class baseClass = object_getClass(delegate);
    NSString *className = NSStringFromClass(baseClass);

  

}


@end

#pragma mark -

@implementation FTWKWebViewDelegateProxy (SubclassMethod)

/// Overridden instance class method
- (Class)class {
    if (self.dataFlux_className) {
        return NSClassFromString(self.dataFlux_className);
    }
    return [super class];
}
// request
-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] addRequest:navigationAction.request webView:webView];
    }
    [FTWKWebViewDelegateProxy invokeWithTarget:self selector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:) webView:webView arg1:navigationAction arg2:decisionHandler];
}
//response
-(void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] addResponse:navigationResponse.response webView:webView];
    }
    [FTWKWebViewDelegateProxy invokeWithTarget:self selector:@selector(webView:decidePolicyForNavigationResponse:decisionHandler:) webView:webView arg1:navigationResponse arg2:decisionHandler];
}
//load error
-(void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] didRequestFailWithError:error webView:webView];
    }
    [FTWKWebViewDelegateProxy invokeWithTarget:self selector:@selector(webView:didFailProvisionalNavigation:withError:) webView:webView arg1:navigation arg2:error];
}
//webView:didCommitNavigation:
-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] loadingWebView:webView];
    }
    [FTWKWebViewDelegateProxy invokeWithTarget:self selector:@selector(webView:didCommitNavigation:) webView:webView arg1:navigation arg2:nil];
}
//navigation Finish
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        [[FTWKWebViewHandler sharedInstance] didFinishWithWebview:webView];
    }
    [FTWKWebViewDelegateProxy invokeWithTarget:self selector:@selector(webView:didFinishNavigation:) webView:webView arg1:navigation arg2:nil];

}

+ (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel {
    //如果cls继承自NSProxy，使用respondsToSelector来判断会崩溃
    //因为NSProxy本身未实现respondsToSelector
    return class_respondsToSelector(cls, sel);
}
+ (void)invokeWithTarget:(NSObject *)target selector:(SEL)selector webView:(WKWebView *)webView arg1:(id)arg1 arg2:(id)arg2{
    Class originalClass = NSClassFromString(target.dataFlux_className) ?: target.superclass;
    if([FTSwizzler realDelegateClass:originalClass respondsToSelector:@selector(webView:didFinishNavigation:)]){
        struct objc_super targetSuper = {
            .receiver = target,
            .super_class = originalClass
        };
        // 消息转发给原始类
        if(arg2 != nil){
            void (*func)(struct objc_super *, SEL, id, id) = (void *)&objc_msgSendSuper;
            
            func(&targetSuper, selector, arg1, arg2);
        }else{
            void (*func)(struct objc_super *, SEL, id) = (void *)&objc_msgSendSuper;
            
            func(&targetSuper, selector, arg1);
        }
    }
}

@end







