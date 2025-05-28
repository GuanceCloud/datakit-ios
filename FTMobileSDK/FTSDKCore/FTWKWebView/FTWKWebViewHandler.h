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
/// webView 添加  web 端 rum 数据
@protocol FTWKWebViewRumDelegate <NSObject>
@optional
- (void)dealReceiveScriptMessage:(id )message slotId:(NSUInteger)slotId;

@end
/// 处理 WKWebView Trace、js 交互
@interface FTWKWebViewHandler : NSObject<WKNavigationDelegate>
+ (instancetype)sharedInstance;

- (void)startWithEnableTraceWebView:(BOOL)enable allowWebViewHost:(NSArray *)hosts rumDelegate:(id<FTWKWebViewRumDelegate>)delegate;

- (void)enableTrackingWebView:(WKWebView *)webView;

- (void)addScriptMessageHandlerWithWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END
#endif
