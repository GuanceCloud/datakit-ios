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
 * 日志上报
 * @param content  日志内容，可为json字符串
 * @param status   事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info

 */
-(void)logging:(NSString *)content status:(FTStatus)status;

/**
 * 绑定用户信息
 * @param Id        用户Id
*/
- (void)bindUserWithUserID:(NSString *)Id;


-(void)startTrackExtensionCrashWithApplicationGroupIdentifier:(NSString *)groupIdentifier;

/**
 * 注销当前用户
*/
- (void)logout;


@end

NS_ASSUME_NONNULL_END
