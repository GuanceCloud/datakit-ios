//
//  FTWKWebViewHandler+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/5/28.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTWKWebViewHandler.h"
#if !TARGET_OS_TV
NS_ASSUME_NONNULL_BEGIN
/// webView add web-side rum data
@protocol FTWKWebViewRumDelegate <NSObject>
- (void)dealRUMWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
- (nullable NSString *)getLastHasReplayViewID;
- (nullable NSString *)getLastViewName;

@end
@interface FTWKWebViewHandler ()

@property (nonatomic, copy) NSArray *whiteLists;

- (void)startWithEnableTraceWebView:(BOOL)enable allowWebViewHost:(nullable NSArray *)hosts rumDelegate:(id<FTWKWebViewRumDelegate>)delegate;

- (void)innerEnableWebView:(WKWebView *)webView;

- (void)disableWebView:(WKWebView *)webView;

+ (void)shutDown;
@end
NS_ASSUME_NONNULL_END
#endif
