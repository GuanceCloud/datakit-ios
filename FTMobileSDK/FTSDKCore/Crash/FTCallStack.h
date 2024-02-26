//
//  FTCallStack.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/09.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FTCallStack : NSObject
+ (NSString *)ft_reportOfThread:(thread_t)thread backtrace:(uintptr_t*)backtraceBuffer count:(int)count;
+ (NSString *)ft_backtraceOfMainThread;
+ (NSString *)ft_backtraceOfNSThread:(NSThread *)thread;
+ (NSString *)ft_crashReportHeader;
+ (NSString *)cpuArch;
@end

NS_ASSUME_NONNULL_END
