//
//  FTRumConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/22.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRumConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTRumConfig ()
/// Private initialization method, initialized through dictionary, used for Extension SDK
/// - Parameter dict: dictionary converted from config
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// Convert config to dictionary
-(NSDictionary *)convertToDictionary;
/// Merge remote config
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
