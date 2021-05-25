//
//  FTPresetProperty.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTPresetProperty : NSObject
@property (nonatomic, assign) BOOL isSignin;
+ (NSDictionary *)ft_getDeviceInfo;
+ (NSString *)appIdentifier;
+ (NSString *)userid;

/**
 * 初始化方法
 * @param appid   app_id
 * @param version 应用版本号
 * @param env     环境
 * @return 初始化对象
 */
- (instancetype)initWithAppid:(NSString *)appid version:(NSString *)version env:(NSString *)env;
/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/**
 * 获取 Rum InfluxDB 公共Tag
 * @param type 指标集名称类型
 */
- (NSDictionary *)propertyWithType:(NSString *)type;
/**
 * 获取 Rum ES 公共Tag
 * @param type 指标集名称类型
*/
- (NSDictionary *)esPropertyWithType:(NSString *)type terminal:(NSString *)terminal;
/**
 *  重新设置
 */
- (void)resetWithAppid:(NSString *)appid version:(NSString *)version env:(NSString *)env;
@end

NS_ASSUME_NONNULL_END
