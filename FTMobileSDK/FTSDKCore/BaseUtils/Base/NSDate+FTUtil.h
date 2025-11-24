//
//  NSDate+FTUtil.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (FTUtil)
+ (long long)ft_currentMillisecondTimeStamp;
+ (long long)ft_currentNanosecondTimeStamp;
- (long long)ft_nanosecondTimeStamp;
- (NSString *)ft_stringWithBaseFormat;
+ (NSDate *)ft_dateFromBaseFormatString:(NSString *)string;
- (NSString *)ft_stringWithGMTFormat;
- (NSNumber *)ft_nanosecondTimeIntervalToDate:(NSDate *)toDate;
@end

NS_ASSUME_NONNULL_END
