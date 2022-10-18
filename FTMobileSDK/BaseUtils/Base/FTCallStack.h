//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/09.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTCallStack : NSObject

//+ (NSString *)ft_backtraceOfAllThread;
//+ (NSString *)ft_backtraceOfCurrentThread;
+ (NSString *)ft_backtraceOfMainThread;
+ (NSString *)ft_backtraceOfNSThread:(NSThread *)thread;
+ (NSString *)ft_crashReportHeader;
+ (NSString *)getMachine:(cpu_type_t)cputype;
@end

NS_ASSUME_NONNULL_END
