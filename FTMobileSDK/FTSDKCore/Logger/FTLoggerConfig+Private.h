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
/// 私有的初始化方法，通过字典来初始化，用于 Extensin SDK
/// - Parameter dict: config 转化后的字典
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// 将 config 转化成字典
-(NSDictionary *)convertToDictionary;
/// 合并 remoteConfig
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
