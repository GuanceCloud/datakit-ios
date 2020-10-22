//
//  FTWKWebViewHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "FTMobileConfig.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTWKWebViewTraceDelegate <NSObject>
@optional
/**
 * WKWebView Trace
 */
- (void)ftWKWebViewTraceRequest:(NSURLRequest *)request response:(nullable NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(nullable NSError *)error;
/**
 * mobile_webview_http
*/
- (void)ftWKWebViewTraceRequest:(NSURLRequest *)request isError:(BOOL)isError;
/**
 * mobile_webview_time_cost   loading
 * ⻚面开始 - 开始加载资源
 */
-(void)ftWKWebViewLoadingWithURL:(NSURL *)url duration:(NSNumber *)duration;
/**
 * mobile_webview_time_cost   loadCompleted
 * ⻚面开始 - 资源加载完毕
*/
-(void)ftWKWebViewLoadCompletedWithURL:(NSURL *)url duration:(NSNumber *)duration;
@end
@interface FTWKWebViewHandler : NSObject<WKNavigationDelegate>
@property (nonatomic, assign) BOOL trace;
@property (nonatomic, weak) id<FTWKWebViewTraceDelegate> traceDelegate;
+ (instancetype)sharedInstance;
- (void)addWebView:(WKWebView *)webView;
- (void)reloadWebView:(WKWebView *)webView completionHandler:(void (^)(NSURLRequest *request,BOOL needTrace))completionHandler;
- (void)addRequest:(NSURLRequest *)request webView:(WKWebView *)webView;
- (void)addResponse:(NSURLResponse *)response webView:(WKWebView *)webView;
- (void)removeWebView:(WKWebView *)webView;
- (void)didRequestFailWithError:(NSError *)error webView:(WKWebView *)webview;
- (void)loadingWebView:(WKWebView *)webView;
- (void)didFinishWithWebview:(WKWebView *)webview;

@end

NS_ASSUME_NONNULL_END
