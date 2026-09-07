//
//  FTWKWebViewHandler+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/5/28.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTWKWebViewHandler.h"
#import "FTWeakMapTable.h"
#import "FTWKWebViewRumDelegate.h"
#import "FTWKWebViewLogDelegate.h"
#import <TargetConditionals.h>
#if !TARGET_OS_TV
NS_ASSUME_NONNULL_BEGIN

@interface FTWKWebViewHandler ()

/// Configures shared hosts without changing either module's switch or delegate.
- (void)setAllowWebViewHost:(nullable NSArray *)hosts;

/// Configures WebView RUM without changing shared hosts or Log configuration.
- (void)startWithEnableTraceWebView:(BOOL)enable rumDelegate:(nullable id<FTWKWebViewRumDelegate>)delegate;

/// Configures WebView Log, including remote refresh, without changing hosts or RUM.
- (void)startWithEnableWebViewLog:(BOOL)enable logDelegate:(nullable id<FTWKWebViewLogDelegate>)delegate;

- (void)innerEnableWebView:(WKWebView *)webView;

- (void)disableWebView:(WKWebView *)webView;

+ (void)shutDown;
@end
NS_ASSUME_NONNULL_END
#endif
