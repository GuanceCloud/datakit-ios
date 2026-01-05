//
//  FTConfig+RemoteConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/12/24.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTMobileConfig.h"
#import "FTRumConfig.h"
#import "FTLoggerConfig.h"
#import "FTRemoteConfigModel.h"

@interface FTMobileConfig (RemoteConfig)
-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model;
@end

@interface FTRumConfig (RemoteConfig)
-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model;
@end

@interface FTLoggerConfig (RemoteConfig)
-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model;
@end

@interface FTTraceConfig (RemoteConfig)
-(void)mergeWithRemoteConfigModel:(FTRemoteConfigModel *)model;
@end
