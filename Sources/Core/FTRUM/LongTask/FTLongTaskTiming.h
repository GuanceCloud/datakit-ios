//
//  FTLongTaskTiming.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/26.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTLongTaskDetector.h"

NS_ASSUME_NONNULL_BEGIN

/// A coherent copy of one main-thread RunLoop callback. Times are nanoseconds.
/// sequence is the even publication version; sequence / 2 identifies the interval.
/// Epoch time locates the event; continuous time bounds its effective duration.
typedef struct {
    uint64_t sequence;
    CFRunLoopActivity activity;
    BOOL running;
    long long startTimeNs;
    uint64_t startContinuousNs;
} FTLongTaskRunLoopSnapshot;

typedef NS_ENUM(NSUInteger, FTLongTaskPhase) {
    FTLongTaskPhaseBegin, FTLongTaskPhaseCheckpoint, FTLongTaskPhaseEnd
};
typedef struct {
    FTLongTaskPhase phase;
    uint64_t generation;
    long long startTimeNs;
    long long observationTimeNs;
    uint64_t durationNs;
} FTLongTaskTiming;

/// Internal interface: return an absolute checkpoint on the effective-duration axis.
/// UINT64_MAX means no more business checkpoints, but End is still delivered.
@protocol FTLongTaskTimingDelegate <NSObject>
- (uint64_t)longTaskDetector:(FTLongTaskDetector *)detector didObserveTiming:(FTLongTaskTiming)timing;
@end
@interface FTLongTaskDetector (Timing)
- (void)performAsynchronousBlock:(dispatch_block_t)block;
- (BOOL)isMonitoringGeneration:(uint64_t)generation;
@end
NS_ASSUME_NONNULL_END
