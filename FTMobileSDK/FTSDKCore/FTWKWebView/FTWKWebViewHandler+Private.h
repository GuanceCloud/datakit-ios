//
//  FTWKWebViewHandler+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/5/28.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTWKWebViewHandler.h"
#import "FTWeakMapTable.h"
#import "FTWKWebViewRumDelegate.h"
#if !TARGET_OS_TV
NS_ASSUME_NONNULL_BEGIN

@interface FTWKWebViewHandler ()

@property (nonatomic, copy) NSArray *whiteLists;
/**
 * key:viewController
 * value:linkRumInfos
 */
@property (nonatomic, strong) FTWeakMapTable *linkRumInfos;

- (void)startWithEnableTraceWebView:(BOOL)enable allowWebViewHost:(nullable NSArray *)hosts rumDelegate:(id<FTWKWebViewRumDelegate>)delegate;

- (void)innerEnableWebView:(WKWebView *)webView;

- (void)disableWebView:(WKWebView *)webView;

+ (void)shutDown;
@end
NS_ASSUME_NONNULL_END
#endif
