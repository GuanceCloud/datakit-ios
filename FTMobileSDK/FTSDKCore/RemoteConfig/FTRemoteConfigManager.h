//
//  FTRemoteConfigManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/5.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRemoteConfigurationProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTRemoteConfigManager : NSObject<FTRemoteConfigurationDataSource>

@property (nonatomic, weak) id<FTRemoteConfigurationProtocol> delegate;

+ (instancetype)sharedInstance;

- (void)enable:(BOOL)enable updateInterval:(int)updateInterval;
/// Request remote configuration
- (void)updateRemoteConfig;

- (void)updateRemoteConfigWithMiniUpdateInterval:(int)miniUpdateInterval callback:(nullable void (^)(BOOL, NSDictionary<NSString *,id> * _Nullable))callback;
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
