//
//  FTDateUtil.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 时间工具类
@interface FTDateUtil : NSObject
/// 获取当前时间戳 豪秒级
+ (long long)currentTimeMillisecond;
/// 获取给定时间的时间戳 纳秒级
/// @param date 时间
+ (long long)dateTimeNanosecond:(NSDate *)date;
/// 获取当前时间戳 纳秒级
+ (long long)currentTimeNanosecond;
/// 获取GMT格式的时间
+ (NSString *)currentTimeGMT;
/// 获取时间间隔 纳秒级
/// - Parameters:
///   - date: 起始时间
///   - toDate: 终止时间
+ (NSNumber *)nanosecondTimeIntervalSinceDate:(NSDate *)date toDate:(NSDate *)toDate;
@end

NS_ASSUME_NONNULL_END
