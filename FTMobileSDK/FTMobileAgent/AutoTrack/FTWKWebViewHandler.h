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

-(void)ftAddScriptMessageHandlerWithWebView:(WKWebView *)webView;

@end
@interface FTWKWebViewHandler : NSObject<WKNavigationDelegate>
@property (nonatomic, assign) BOOL enableTrace;
@property (nonatomic, weak) id<FTWKWebViewTraceDelegate> traceDelegate;
+ (instancetype)sharedInstance;
- (void)addWebView:(WKWebView *)webView;
- (void)reloadWebView:(WKWebView *)webView completionHandler:(void (^)(NSURLRequest *request,BOOL needTrace))completionHandler;
- (void)addRequest:(NSURLRequest *)request webView:(WKWebView *)webView;
- (void)addResponse:(NSURLResponse *)response webView:(WKWebView *)webView;
- (void)didRequestFailWithError:(NSError *)error webView:(WKWebView *)webView;
- (void)removeWebView:(WKWebView *)webView;


- (void)addScriptMessageHandlerWithWebView:(WKWebView *)webView;
@end

NS_ASSUME_NONNULL_END
