//
//  FTThreadInspector.h
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "FTCrashThread.h"

NS_ASSUME_NONNULL_BEGIN
@class FTThread;
@interface FTThreadInspector : NSObject
- (NSArray<FTThread *> *)getCurrentThreads;

// Anr\longTask
- (NSArray<FTThread *> *)getCurrentThreadsWithStackTrace;

- (nullable NSString *)getThreadName:(FTCrashThread)thread;
@end

NS_ASSUME_NONNULL_END
