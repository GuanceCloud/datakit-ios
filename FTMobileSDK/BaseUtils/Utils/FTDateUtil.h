//
//  FTDateUtil.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTDateUtil : NSObject
/**
 *  @abstract
 *  获取当前时间戳 豪秒级
 *
 *  @return 时间戳
*/
+ (long long)currentTimeMillisecond;
+ (long long)dateTimeNanosecond:(NSDate *)date;
/**
 *  @abstract
 *  获取当前时间戳 纳秒级
 *
 *  @return 时间戳
*/
+ (long long)currentTimeNanosecond;
/**
 *  @abstract
 *  获取GMT格式的时间
 *
 *  @return GMT格式的时间
*/

+ (NSString *)currentTimeGMT;
/**
 *  @abstract
 *  获取时间间隔 纳秒级
 *
 *  @return 时间间隔
*/
+ (NSNumber *)microcrosecondtimeIntervalSinceDate:(NSDate *)anotherDate toDate:(NSDate *)toDate;
/**
 *  @abstract
 *  获取时间间隔 微秒级
 *
 *  @return 时间间隔
*/
+ (NSNumber *)nanotimeIntervalSinceDate:(NSDate *)anotherDate toDate:(NSDate *)toDate;
@end

NS_ASSUME_NONNULL_END
