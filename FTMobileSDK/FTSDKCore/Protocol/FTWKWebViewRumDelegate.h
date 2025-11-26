//
//  FTWKWebViewRumDelegate.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/11/18.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#ifndef FTWKWebViewRumDelegate_h
#define FTWKWebViewRumDelegate_h
NS_ASSUME_NONNULL_BEGIN
@protocol FTWKWebViewRumDelegate <NSObject>
@required
- (void)dealRUMWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
- (NSString *)getLastHasReplayViewID;
- (void)bindSRInfo:(NSDictionary *)info containerViewID:(NSString *)viewID;
- (nullable NSString *)getLastViewName;
@end
NS_ASSUME_NONNULL_END
#endif /* FTWKWebViewRumDelegate_h */
