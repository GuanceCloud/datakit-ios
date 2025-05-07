//
//  FTMobileConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTMobileConfig.h"
#import "FTLoggerConfig.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTMobileConfig ()
/// 添加 pkg 信息
/// - Parameters:
///   - key: 平台
///   - value: 版本号
- (void)addPkgInfo:(NSString *)key value:(NSString *)value;
/// 其他平台 pkg 信息
- (NSDictionary *)pkgInfo;
/// 私有的初始化方法，通过字典来初始化，用于 Extensin SDK,同步 service
/// - Parameter dict: config 转化后的字典
-(instancetype)initWithDictionary:(NSDictionary *)dict;
/// 将 config 转化成字典
-(NSDictionary *)convertToDictionary;
@end

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
