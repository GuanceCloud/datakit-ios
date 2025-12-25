//
//  FTRemoteConfigurationProtocol.h
//
//  Created by hulilei on 2025/6/5.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#ifndef FTRemoteConfigurationProtocol_h
#define FTRemoteConfigurationProtocol_h


NS_ASSUME_NONNULL_BEGIN

@protocol FTRemoteConfigurationProtocol <NSObject>

- (void)remoteConfigurationDidChange;

@end

@protocol FTRemoteConfigurationDataSource <NSObject>

- (nullable NSDictionary *)getLastFetchedRemoteConfig;

@end

NS_ASSUME_NONNULL_END
#endif /* FTRemoteConfigurationProtocol_h */
