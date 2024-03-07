//
//  NSDate+FTUtil.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "NSDate+FTUtil.h"

@implementation NSDate (FTUtil)
+ (long long)ft_currentMillisecondTimeStamp {
    return (long long) ([[NSDate date] timeIntervalSince1970] * 1000);
}
+ (long long)ft_currentNanosecondTimeStamp{
    NSDate *dateNow = [NSDate date];
    return (long long) ([dateNow timeIntervalSince1970] * 1000000000);
}
- (long long)ft_nanosecondTimeStamp{
    long long time= (long long)([self timeIntervalSince1970]*1000000000);
    return  time;
}
- (NSString *)ft_stringWithBaseFormat{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc]init];
        [formatter setLocale:[NSLocale currentLocale]];
        formatter.dateFormat=@"yyyy-MM-dd HH:mm:ss:SSS";
    });
    return [formatter stringFromDate:self];
}
- (NSString *)ft_stringWithGMTFormat{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSTimeZone *tzGMT = [NSTimeZone timeZoneWithName:@"GMT"];
        formatter=[[NSDateFormatter alloc]init];
        formatter.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
        formatter.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US"];
        formatter.timeZone = tzGMT;
    });
    return [formatter stringFromDate:self];
}
- (NSNumber *)ft_nanosecondTimeIntervalToDate:(NSDate *)toDate{
    if(toDate){
        return [NSNumber numberWithLongLong:[toDate timeIntervalSinceDate:self]*1000000000];
    }
    return @0;
}

@end
