//
//  TestWKProxy.m
//  App
//
//  Created by hulilei on 2021/8/3.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
