//
//  NSDate+FTAdd.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/7/23.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "NSDate+FTAdd.h"

@implementation NSDate (FTAdd)
-(long long)ft_dateTimestamp{
    long long time= (long long)([self timeIntervalSince1970]*1000000000);
    return  time;
}
-(long long)ft_msDateTimestamp{
    long long time= (long long)([self timeIntervalSince1970]*1000);
    return  time;
}
-(NSString *)ft_dateGMT{
        
    NSTimeZone *tzGMT = [NSTimeZone timeZoneWithName:@"GMT"];
    
    [NSTimeZone setDefaultTimeZone:tzGMT];
    
    NSDateFormatter *iosDateFormater=[[NSDateFormatter alloc]init];
    
    iosDateFormater.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
    
    iosDateFormater.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US"];
    
    return [iosDateFormater stringFromDate:self];
}
-(NSNumber *)ft_microcrosecondtimeIntervalSinceDate:(NSDate *)anotherDate{
    return  [NSNumber numberWithLong:[self timeIntervalSinceDate:anotherDate]*1000000];
}
-(NSNumber *)ft_nanotimeIntervalSinceDate:(NSDate *)anotherDate{
    return  [NSNumber numberWithLong:[self timeIntervalSinceDate:anotherDate]*1000000000];
}
@end
