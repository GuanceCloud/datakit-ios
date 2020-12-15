//
//  NSDate+FTAdd.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/7/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (FTAdd)
/**
 *  @abstract
 *  获取当前时间戳 毫秒级
 *
 *  @return 时间戳
*/
-(long long)ft_dateTimestamp;
/**
 *  @abstract
 *  获取GMT格式的时间
 *
 *  @return GMT格式的时间
*/
-(NSString *)ft_dateGMT;
/**
 *  @abstract
 *  获取时间间隔 纳秒级
 *
 *  @return 时间间隔
*/
-(NSNumber *)ft_timeIntervalSinceDate:(NSDate *)anotherDate;
@end

NS_ASSUME_NONNULL_END
