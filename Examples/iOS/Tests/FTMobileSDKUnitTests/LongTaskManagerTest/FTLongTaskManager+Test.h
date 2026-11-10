//
//  FTLongTaskManager+Test.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/12.
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

#import "FTLongTaskManager.h"
#import "FTLongTaskANRData.h"
#import "FTLongTaskTiming.h"
#import "FTANRProcessor.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTLongTaskManager (Test) <FTLongTaskTimingDelegate>
@end

@interface FTManualTimingDetector : FTLongTaskDetector
@end

static inline FTANRProcessor *FTTestANRProcessor(FTLongTaskManager *manager) {
    return [manager valueForKey:@"anrProcessor"];
}

static inline FTLongTaskANRDataStore *FTTestANRStore(FTLongTaskManager *manager) {
    return FTTestANRProcessor(manager).dataStore;
}

static inline void FTTestDrainDetector(FTLongTaskDetector *detector) {
    dispatch_sync([detector valueForKey:@"longTaskQueue"], ^{});
}

static inline uint64_t FTTestObserveLongTaskState(FTLongTaskManager *manager, FTLongTaskPhase phase,
                                               long long startNs, uint64_t durationNs, long long endNs,
                                               FTAppState startState, FTRUMAppState appState) {
    FTManualTimingDetector *detector = [[FTManualTimingDetector alloc] initWithDelegate:manager];
    FTLongTaskTiming timing = {.phase = phase, .generation = 42, .startTimeNs = startNs,
        .observationTimeNs = endNs, .durationNs = durationNs, .startAppState = startState, .appState = appState};
    return [manager longTaskDetector:detector didObserveTiming:timing];
}

static inline uint64_t FTTestObserveLongTask(FTLongTaskManager *manager, FTLongTaskPhase phase,
                                          long long startNs, uint64_t durationNs, long long endNs) {
    return FTTestObserveLongTaskState(manager, phase, startNs, durationNs, endNs,
                                     FTAppStateUnknown, FTRUMAppStateUnknown);
}

NS_ASSUME_NONNULL_END
