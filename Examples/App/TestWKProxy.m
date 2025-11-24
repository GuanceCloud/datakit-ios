//
//  TestWKProxy.m
//  App
//
//  Created by hulilei on 2021/8/3.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "TestWKProxy.h"
#import <WebKit/WKWebView.h>
@interface TestWKProxy (){
    __weak id _wkwebviewTarget;
}
@end
@implementation TestWKProxy
- (instancetype)initWithWKWebViewTarget:(nullable id<WKNavigationDelegate>)wkwebViewTarget{
    // -[NSProxy init] is undefined
    if (self) {
        _wkwebviewTarget = wkwebViewTarget;
    }
    return self;
}
- (BOOL)respondsToSelector:(SEL)aSelector {
    return   [_wkwebviewTarget respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
   
    return _wkwebviewTarget;
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    void *nullPointer = NULL;
    [invocation setReturnValue:&nullPointer];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

@end
