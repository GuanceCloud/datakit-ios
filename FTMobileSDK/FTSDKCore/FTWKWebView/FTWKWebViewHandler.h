//
//  FTWKWebViewHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//
#import <Foundation/Foundation.h>
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
