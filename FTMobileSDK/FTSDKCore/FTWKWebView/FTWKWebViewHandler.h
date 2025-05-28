//
//  FTWKWebViewHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//
#import <Foundation/Foundation.h>
#if !TARGET_OS_TV
#import <WebKit/WebKit.h>
NS_ASSUME_NONNULL_BEGIN

/// 处理 WKWebView RUM 事件与 本机 RUM 会话关联
@interface FTWKWebViewHandler : NSObject

+ (instancetype)sharedInstance;

/// 使 SDK 能够将来自 WebView 的 RUM 事件与本机 RUM 会话关联起来。
/// - Parameter webView: 采集的 webView
- (void)enableWebView:(WKWebView *)webView;

/// 使 SDK 能够将来自 WebView 的 RUM 事件与本机 RUM 会话关联起来。
/// - Parameters:
///   - webView: 采集的 webView
///   - hosts: 一组使用 Web SDK 进行检测的主机地址数组。
- (void)enableWebView:(WKWebView *)webView allowWebViewHost:(NSArray *)hosts;

@end

NS_ASSUME_NONNULL_END
#endif
