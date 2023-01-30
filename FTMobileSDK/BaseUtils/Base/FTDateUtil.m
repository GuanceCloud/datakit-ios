//
//  FTDateUtil.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTDateUtil.h"

@implementation FTDateUtil
+ (long long)currentTimeMillisecond {
    NSDate *dateNow = [NSDate date];
    return (long long) ([dateNow timeIntervalSince1970] * 1000);
}
+ (long long)currentTimeNanosecond{
    NSDate *dateNow = [NSDate date];
    return (long long) ([dateNow timeIntervalSince1970] * 1000000000);
}
+ (long long)dateTimeNanosecond:(NSDate *)date{
    long long time= (long long)([date timeIntervalSince1970]*1000000000);
    return  time;
}
+ (NSString *)currentTimeGMT{
    NSTimeZone *tzGMT = [NSTimeZone timeZoneWithName:@"GMT"];
    NSDateFormatter *iosDateFormatter=[[NSDateFormatter alloc]init];
    iosDateFormatter.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
    iosDateFormatter.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US"];
    iosDateFormatter.timeZone = tzGMT;
    return [iosDateFormatter stringFromDate:[NSDate date]];
}
+ (NSNumber *)nanosecondTimeIntervalSinceDate:(NSDate *)date toDate:(NSDate *)toDate{
    return  [NSNumber numberWithLong:[toDate timeIntervalSinceDate:date]*1000000000];
}
@end
