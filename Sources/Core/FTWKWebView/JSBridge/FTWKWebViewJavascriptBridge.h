//
//  FTWKWebViewJavascriptBridge.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/1/5.
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

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if !TARGET_OS_TV
#import <WebKit/WebKit.h>
#import "FTWebViewJavascriptBridgeBase.h"

NS_ASSUME_NONNULL_BEGIN
@interface FTBindInfo:NSObject
@property (nonatomic, copy, nullable) NSString *viewReferrer;
@property (nonatomic, copy, nullable) NSString *viewId;
@property (nonatomic, weak, nullable) WKWebView *container;
@end

@interface FTWKWebViewJavascriptBridge : NSObject<FTWebViewJavascriptBridgeBaseDelegate,WKScriptMessageHandler>
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
