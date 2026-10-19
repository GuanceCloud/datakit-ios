//
//  FTRUMAppStateHistory.h
//  FTMobileSDK
//
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

#import <Foundation/Foundation.h>
#import "FTInternalConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class FTRUMAppStateHistory;
@protocol FTRUMAppStateHistoryDelegate <NSObject>
- (void)appStateHistory:(FTRUMAppStateHistory *)history
        didChangeState:(FTRUMAppState)state
                  time:(NSDate *)time;
@end

@interface FTRUMAppStateHistory : NSObject
@property (nonatomic, weak, nullable) id<FTRUMAppStateHistoryDelegate> delegate;
/// False after a wall-clock regression; lifecycle control must still be delivered.
@property (nonatomic, assign, readonly, getter=isTimeComparable) BOOL timeComparable;
// Monitoring is explicit; standalone histories do not subscribe automatically.
- (void)startMonitoring;
- (void)stopMonitoring;
// Unix epoch nanoseconds captured on entry to the lifecycle delegate callback.
- (instancetype)initWithState:(NSString *)state timeNs:(long long)timeNs;
/// Preserve actual background admission independently from startup/unknown display state.
- (instancetype)initWithState:(NSString *)state timeNs:(long long)timeNs background:(BOOL)background;
/// Inclusive start, exclusive end (a zero-length interval checks its start).
/// Explicit inactive/unknown observations are allowed; absent or incomparable history is not.
- (BOOL)hasBackgroundOrUnavailableHistoryFrom:(long long)startNs to:(long long)endNs;
- (BOOL)recordState:(NSString *)state timeNs:(long long)timeNs;
- (NSString *)stateAt:(long long)timeNs;
// Interval queries use [start, end) and aggregate only known foreground/background states.
// All-unknown intervals, missing coverage and incomparable clocks return unknown.
- (NSString *)stateFrom:(long long)startNs duration:(long long)durationNs;
- (NSString *)stateFrom:(long long)startNs to:(long long)endNs;
@end

NS_ASSUME_NONNULL_END
