//
//  ZYConfig.h
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/6.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
/* SDK版本 */
#define ZY_SDK_VERSION @"1.0.0"

/* 默认应用版本 */
#define ZY_APP_VERSION [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]



NS_ASSUME_NONNULL_BEGIN

@interface FTMobileConfig : NSObject
#pragma mark - 基本设置
// SDK版本
@property (nonatomic, copy) NSString *sdkVersion;

// 应用版本(默认:info.plist中CFBundleShortVersionString对应的值)
@property (nonatomic, copy) NSString *sdkUUID;
@property (nonatomic, copy) NSString *appVersion;

//应用名称（默认：info.plist中的CFBundleDisplayName）
@property (nonatomic ,copy) NSString *appName;
@property (nonatomic, copy) NSString *metricsUrl;

@property (nonatomic, assign) BOOL enableRequestSigning;

@property (nonatomic, copy) NSString *akId;

@property (nonatomic, copy) NSString *akSecret;
@end

NS_ASSUME_NONNULL_END
