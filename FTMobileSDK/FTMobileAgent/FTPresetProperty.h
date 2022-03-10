//
//  FTPresetProperty.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTPresetProperty : NSObject
@property (nonatomic, assign) BOOL isSignin;
@property (nonatomic, copy) NSString *appid;
@property (nonatomic, strong) NSDictionary *logContext;
@property (nonatomic, strong) NSDictionary *rumContext;
+ (NSString *)deviceInfo;
+ (NSString *)appIdentifier;
+ (NSString *)userid;
+ (NSString *)telephonyInfo;

/**
 * 初始化方法
 * @param config 应用版本号
 * @return 初始化对象
 */
- (instancetype)initWithMobileConfig:(FTMobileConfig *)config;
/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/**
 * 获取 Rum ES 公共Tag
*/
- (NSDictionary *)rumPropertyWithTerminal:(NSString *)terminal;
/**
 * 获取 logger base Tag
 */
- (NSDictionary *)loggerPropertyWithStatus:(FTLogStatus)status serviceName:(NSString *)serviceName;
/**
 * 获取 trace base Tag
 */
- (NSDictionary *)traceProperty;
/**
 *  重新设置
 */
- (void)resetWithMobileConfig:(FTMobileConfig *)config;
@end

NS_ASSUME_NONNULL_END
