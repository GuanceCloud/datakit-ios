//
//  FTWKWebViewJavascriptBridge.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/1/5.
//  Copyright © 2021 hll. All rights reserved.
//
#import <Foundation/Foundation.h>
#if !TARGET_OS_TV
#import <WebKit/WebKit.h>
#import "FTWebViewJavascriptBridgeBase.h"

NS_ASSUME_NONNULL_BEGIN
@interface FTBindInfo:NSObject
@property (nonatomic, copy) NSString *viewReferrer;
@property (nonatomic, copy) NSString *viewId;
@property (nonatomic, strong) NSDictionary *bindInfo;
@end

@interface FTWKWebViewJavascriptBridge : NSObject<FTWebViewJavascriptBridgeBaseDelegate,WKScriptMessageHandler>
@property (nonatomic, strong) FTBindInfo *bindInfo;
+ (instancetype)bridgeForWebView:(WKWebView*)webView allowWebViewHostsString:(NSString *)hostsString;
- (void)removeScriptMessageHandler;
- (void)registerHandler:(NSString*)handlerName handler:(nullable WVJBHandler)handler;
- (void)removeHandler:( NSString* )handlerName;
- (void)callHandler:(NSString*)handlerName;
- (void)callHandler:(NSString*)handlerName data:(nullable id)data;
- (void)callHandler:(NSString*)handlerName data:(nullable id)data responseCallback:(nullable WVJBResponseCallback)responseCallback;

@end

NS_ASSUME_NONNULL_END
#endif
