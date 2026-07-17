//
//  NSDate+FTUtil.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "NSDate+FTUtil.h"

@implementation NSDate (FTUtil)
+ (long long)ft_currentMillisecondTimeStamp {
    return (long long) ([[NSDate date] timeIntervalSince1970] * 1000);
}
+ (long long)ft_currentNanosecondTimeStamp{
    NSDate *dateNow = [NSDate date];
    return (long long) ([dateNow timeIntervalSince1970] * 1e9);
}
- (long long)ft_millisecondTimeStamp{
    long long time= (long long)([self timeIntervalSince1970]*1000);
    return  time;
}
- (long long)ft_nanosecondTimeStamp{
    long long time= (long long)([self timeIntervalSince1970] * 1e9);
    return  time;
}

- (NSString *)ft_stringWithBaseFormat{
    return [NSDate.ft_baseFormat stringFromDate:self];
}
+ (NSDateFormatter *)ft_baseFormat{
    static dispatch_once_t onceToken;
    static NSDateFormatter *baseFormatter = nil;
    dispatch_once(&onceToken, ^{
        baseFormatter = [[NSDateFormatter alloc]init];
        [baseFormatter setLocale:[NSLocale currentLocale]];
        baseFormatter.dateFormat=@"yyyy-MM-dd--HH:mm:ss:SSS";
    });
    return baseFormatter;
}
+ (NSDate *)ft_dateFromBaseFormatString:(NSString *)string{
    return [self.ft_baseFormat dateFromString:string];
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
        return [NSNumber numberWithLongLong:[toDate timeIntervalSinceDate:self]*1e9];
    }
    return @0;
}

@end
