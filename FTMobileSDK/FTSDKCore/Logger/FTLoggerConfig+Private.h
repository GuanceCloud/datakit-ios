//
//  FTLoggerConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/6.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTLoggerConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTLoggerConfig ()
/// Private initialization method, initialized through dictionary, used for Extension SDK
/// - Parameter dict: Dictionary converted from config
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// Convert config to dictionary
-(NSDictionary *)convertToDictionary;

@end

NS_ASSUME_NONNULL_END
