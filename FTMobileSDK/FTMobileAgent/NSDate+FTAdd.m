//
//  NSDate+FTAdd.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/7/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import "NSDate+FTAdd.h"

@implementation NSDate (FTAdd)
-(long long)ft_dateTimestamp{
    long long time= (long long)([self timeIntervalSince1970]*1000*1000);
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
@end
