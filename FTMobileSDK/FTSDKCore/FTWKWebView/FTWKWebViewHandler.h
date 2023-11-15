//
//  FTWKWebViewHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "FTURLSessionInterceptorProtocol.h"
NS_ASSUME_NONNULL_BEGIN
/// webView 添加  web 端 rum 数据
@protocol FTWKWebViewRumDelegate <NSObject>
@optional

-(void)ftAddScriptMessageHandlerWithWebView:(WKWebView *)webView;

@end
/// 处理 WKWebView Trace、js 交互
@interface FTWKWebViewHandler : NSObject<WKNavigationDelegate>
@property (nonatomic, assign) BOOL enableTrace;
@property (nonatomic, weak) id<FTWKWebViewRumDelegate> rumTrackDelegate;
@property (nonatomic, weak) id<FTURLSessionInterceptorProtocol> interceptor;
+ (instancetype)sharedInstance;

- (void)reloadWebView:(WKWebView *)webView completionHandler:(void (^)(NSURLRequest *request,BOOL needTrace))completionHandler;

- (void)addWebView:(WKWebView *)webView request:(NSURLRequest *)request;

- (void)removeWebView:(WKWebView *)webView;

- (void)addScriptMessageHandlerWithWebView:(WKWebView *)webView;
@end

NS_ASSUME_NONNULL_END
