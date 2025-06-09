//
//  FTRemoteConfigurationProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/5.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#ifndef FTRemoteConfigurationProtocol_h
#define FTRemoteConfigurationProtocol_h
@protocol FTRemoteConfigurationProtocol <NSObject>

- (void)updateRemoteConfiguration:(NSDictionary *)configuration;

@end

#endif /* FTRemoteConfigurationProtocol_h */
