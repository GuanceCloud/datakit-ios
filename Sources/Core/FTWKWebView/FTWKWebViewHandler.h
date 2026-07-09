//
//  FTWKWebViewHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/16.
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
NS_ASSUME_NONNULL_BEGIN

/// Handle WKWebView RUM events and associate with native RUM sessions
@interface FTWKWebViewHandler : NSObject

+ (instancetype)sharedInstance;

/// Enable the SDK to associate RUM events from WebView with native RUM sessions.
/// Note: Must be used before the webView page loads, otherwise the current loading page won't take effect, only the next page load or navigation will take effect.
/// - Parameter webView: webView to be collected
- (void)enableWebView:(WKWebView *)webView;

/// Enable the SDK to associate RUM events from WebView with native RUM sessions.
/// Note: Must be used before the webView page loads, otherwise the current loading page won't take effect, only the next page load or navigation will take effect.
/// - Parameters:
///   - webView: webView to be collected
///   - hosts: array of host addresses using Web SDK for detection.
- (void)enableWebView:(WKWebView *)webView allowWebViewHost:(NSArray *)hosts;

@end

NS_ASSUME_NONNULL_END
#endif
