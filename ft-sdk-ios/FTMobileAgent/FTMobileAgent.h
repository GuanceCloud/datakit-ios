//
//  ZYInterceptor.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTMobileAgent : NSObject
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
SDK 初始化方法

@param configOptions     配置参数
*/
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;

/**
 追踪自定义事件。
 
 @param field      文件名称
 @param tags       事件属性
 @param values     事件名称
 */
- (void)track:(NSString *)field tags:(nullable NSDictionary*)tags values:(NSDictionary *)values;
/**
主动埋点
 @param field   埋点事件名称
 @param values 埋点数据
*/
- (void)track:(NSString *)field  values:(NSDictionary *)values;
/**
绑定用户信息
 @param name     用户名
 @param Id       用户Id
 @param exts     用户其他信息
*/
- (void)bindUserWithName:(NSString *)name Id:(NSString *)Id exts:(nullable NSDictionary *)exts;
/**
 注销当前用户
*/
- (void)logout;
@end

NS_ASSUME_NONNULL_END
