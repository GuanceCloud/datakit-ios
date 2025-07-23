//
//  FTCallStack.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/10/09.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FTCallStack : NSObject
+ (NSString *)ft_reportOfThread:(thread_t)thread backtrace:(uintptr_t*)backtraceBuffer count:(int)count;
+ (NSString *)ft_backtraceOfMainThread;
+ (NSString *)ft_crashReportHeader;
@end

NS_ASSUME_NONNULL_END
