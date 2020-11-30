//
//  FTMobileAgent.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"

NS_ASSUME_NONNULL_BEGIN
@interface FTMobileAgent : NSObject
#pragma mark ========== init instance ==========
/**
 * 仅用于启动位置信息状态获取
*/
+ (void)startLocation:(nullable void (^)(NSInteger errorCode, NSString * _Nullable errorMessage))callBack;
/**
 * @abstract
 * 返回之前所初始化好的单例
 *
 * @discussion
 * 调用这个方法之前，必须先调用 startWithConfigOptions 这个方法
 *
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;
/**
 * SDK 初始化方法
 * @param configOptions     配置参数
*/
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;

/**
 * 绑定用户信息
 * @param name      用户名
 * @param Id        用户Id
 * @param exts      用户其他信息
*/
- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(nullable NSDictionary *)exts;


-(void)startTrackExtensionCrashWithApplicationGroupIdentifier:(NSString *)groupIdentifier;

/**
 * 注销当前用户
*/
- (void)logout;
/**
 * 清空SDK
 */
- (void)resetInstance;

@end

NS_ASSUME_NONNULL_END
