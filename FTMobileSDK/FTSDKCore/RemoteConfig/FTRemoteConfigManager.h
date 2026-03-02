//
//  FTRemoteConfigManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/5.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRemoteConfigurationProtocol.h"
#import "FTRemoteConfigTypeDefs.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTRemoteConfigManager : NSObject<FTRemoteConfigurationDataSource>

@property (nonatomic, weak) id<FTRemoteConfigurationProtocol> delegate;

@property (nonatomic, strong, readonly) FTRemoteConfigModel *lastRemoteModel;

+ (instancetype)sharedInstance;

- (void)enable:(BOOL)enable updateInterval:(int)updateInterval remoteConfigFetchCompletionBlock:(FTRemoteConfigFetchCompletionBlock)fetchCompletionBlock;
/// Request remote configuration
- (void)updateRemoteConfig;

- (void)updateRemoteConfigWithMinimumUpdateInterval:(NSInteger)minimumUpdateInterval
                                         completion:(nullable FTRemoteConfigFetchCompletionBlock)completion;

- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
