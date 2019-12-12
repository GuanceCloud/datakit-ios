//
//  ZYInterceptor.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTMobileConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTMobileAgent : NSObject

+ (instancetype)sharedInstance;

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
@end

NS_ASSUME_NONNULL_END
