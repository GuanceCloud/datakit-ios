//
//  FTLongTaskManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
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

#import "FTLongTaskANRData.h"
#import "FTRUMDependencies.h"
#import "FTErrorDataProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTLongTaskActiveEvent : NSObject
@property (nonatomic, assign) uint64_t generation;
@property (nonatomic, assign) BOOL mainStackAttempted;
@property (nonatomic, assign) uint64_t effectiveDurationNs;
@property (nonatomic, assign) uint64_t nextFullStackAttemptNs;
@property (nonatomic, assign) uint64_t lastPersistedDurationNs;
@property (nonatomic, assign) long long startTimeNs;
@property (nonatomic, assign) long long lastObservedTimeNs;
@property (nonatomic, assign) long long freezeThresholdNs;
@property (nonatomic, copy, nullable) NSString *mainThreadBacktrace;
@property (nonatomic, copy, nullable) NSString *allThreadsBacktrace;
@property (nonatomic, strong, nullable) FTFatalErrorContextModel *errorContextModel;
@property (nonatomic, assign) BOOL hasPersistedANRData;
@property (nonatomic, assign, readonly) long long durationNs;
@property (nonatomic, assign, readonly) BOOL isANR;
@property (nonatomic, assign, readonly) BOOL isLongTask;
@property (nonatomic, assign, readonly) BOOL needsAllThreadsBacktrace;

- (instancetype)initWithStartTimeNs:(long long)startTimeNs freezeDurationMs:(long)freezeDurationMs;
- (FTLongTaskANRData *)anrData;
@end


@interface FTANRProcessor : NSObject
@property (nonatomic, strong, readonly) FTLongTaskANRDataStore *dataStore;
- (instancetype)initWithDependencies:(FTRUMDependencies *)dependencies backtraceReporting:(id<FTBacktraceReporting>)backtrace;
- (void)updateEvent:(FTLongTaskActiveEvent *)event stillCurrent:(BOOL (^)(void))stillCurrent;
- (uint64_t)nextCheckpointForEvent:(FTLongTaskActiveEvent *)event;
- (void)reportPreviousANRIfFound;
- (long long)reportANRData:(FTLongTaskANRData *)data;
@end
NS_ASSUME_NONNULL_END
