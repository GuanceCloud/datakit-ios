//
//  FTMobileConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTMobileConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTLoggerConfig ()
/// 私有的初始化方法，通过字典来初始化，用于 Extensin SDK
/// - Parameter dict: config 转化后的字典
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// 将 config 转化成字典
-(NSDictionary *)convertToDictionary;
@end

@interface FTRumConfig ()
/// 私有的初始化方法，通过字典来初始化，用于 Extensin SDK
/// - Parameter dict: config 转化后的字典
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// 将 config 转化成字典
-(NSDictionary *)convertToDictionary;
@end

@interface FTTraceConfig ()
/// 私有的初始化方法，通过字典来初始化，用于 Extensin SDK
/// - Parameter dict: config 转化后的字典
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// 将 config 转化成字典
-(NSDictionary *)convertToDictionary;
@end
NS_ASSUME_NONNULL_END
