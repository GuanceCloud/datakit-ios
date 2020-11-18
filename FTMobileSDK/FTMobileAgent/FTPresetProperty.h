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

/**
 * 初始化方法
 * @param sdkTrackVersion SDK 版本
 * @return 初始化对象
 */
- (instancetype)initWithTrackVersion:(NSString *)sdkTrackVersion traceServiceName:(NSString *)serviceName env:(NSString *)env; NS_DESIGNATED_INITIALIZER;
/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
- (NSDictionary *)automaticPropertyTags;
- (NSDictionary *)automaticPropertyFields;
- (NSDictionary *)objectProperties;
- (NSDictionary *)loggingPropertyTags;
+ (NSDictionary *)ft_getDeviceInfo;
@end

NS_ASSUME_NONNULL_END
