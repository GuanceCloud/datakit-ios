//
//  FTCrashReportWrapper.h
//
//  Created by hulilei on 2025/12/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTCrashReportFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTCrashReportWrapper : NSObject<FTCrashReportFilter>

-(NSString *)generateBacktrace:(thread_t)thread;

-(NSString *)generateAllThreadsBacktrace;

@end

NS_ASSUME_NONNULL_END
