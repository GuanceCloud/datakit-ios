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
- (void)track:(nonnull NSString *)field tags:(nullable NSDictionary*)tags values:(nullable NSDictionary *)values;
@end

NS_ASSUME_NONNULL_END
