//
//  FTWebViewJavascriptLeakAvoider.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/1/6.
//  Copyright © 2021 hll. All rights reserved.
//
#import "FTWebViewJavascriptLeakAvoider.h"
#if !TARGET_OS_TV

@implementation FTWebViewJavascriptLeakAvoider
- (instancetype)initWithDelegate:(id <WKScriptMessageHandler> )delegate {
    if (self = [super init]) {
        self.delegate = delegate;
    }
    return self;
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.delegate userContentController:userContentController didReceiveScriptMessage:message];
}

@end
#endif
