//
//  FTExtensionManager.h
//  FTMobileExtension
//
//  Created by 胡蕾蕾 on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
#import "FTExtensionConfig.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTExtensionManager : NSObject
/**
 * @abstract
 * Extension 初始化方法
 *
 * @param extensionConfig extension 配置项
 */
+ (void)startWithExtensionConfig:(FTExtensionConfig *)extensionConfig;

+ (instancetype)sharedInstance;
/**
 * @abstract
 * 日志上报
 *
 * @param content  日志内容，可为json字符串
 * @param status   事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info
 */
-(void)logging:(NSString *)content status:(FTLogStatus)status;
/// 添加自定义日志
/// - Parameters:
///   - content: 日志内容，可为 json 字符串
///   - status: 事件等级和状态
///   - property: 事件自定义属性(可选)
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property;
@end

NS_ASSUME_NONNULL_END
