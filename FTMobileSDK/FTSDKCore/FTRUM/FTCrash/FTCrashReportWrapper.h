//
//  FTCrashReportWrapper.h
//
//  Created by hulilei on 2025/12/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTCrashReportFilter.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTBacktraceReporting;

@interface FTCrashReportWrapper : NSObject<FTCrashReportFilter>

-(void)setEnableMemory:(BOOL)enableMemory;

-(void)setEnableCpu:(BOOL)enableCpu;

-(nullable NSString *)generateBacktrace:(thread_t)thread;

-(nullable NSString *)generateAllThreadsBacktrace;

@end

NS_ASSUME_NONNULL_END
