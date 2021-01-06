//
//  FTWKWebViewJavascriptBridge.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/5.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "FTWebViewJavascriptBridgeBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTWKWebViewJavascriptBridge : NSObject<WKScriptMessageHandler>
+ (instancetype)bridgeForWebView:(WKWebView*)webView;
- (void)registerHandler:(NSString *)handlerName handler:(WVJBHandler)handler;
- (void)removeHandler:( NSString* )handlerName;

@end

NS_ASSUME_NONNULL_END
