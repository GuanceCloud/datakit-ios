//
//  FTLongTaskANRData.h
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

#import <Foundation/Foundation.h>
#import "FTFatalErrorContext.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN long long const FTLongTaskANRDataThresholdNs;
FOUNDATION_EXTERN long long const FTLongTaskANRDataUpdateIntervalNs;

@interface FTLongTaskANRData : NSObject
@property (nonatomic, assign) long long startTimeNs;
@property (nonatomic, assign) long long durationNs;
@property (nonatomic, copy, nullable) NSString *mainThreadBacktrace;
@property (nonatomic, copy, nullable) NSString *allThreadsBacktrace;
@property (nonatomic, strong, nullable) FTFatalErrorContextModel *errorContextModel;
@property (nonatomic, assign) long long lastUpdateTimeNs;
/// Version 3 duration is authoritative; the endpoint is an independent event timestamp.
@property (nonatomic, assign) BOOL usesEffectiveDuration;
@property (nonatomic, assign) long long endTimeNs;

- (instancetype)initWithStartTimeNs:(long long)startTimeNs
                         durationNs:(long long)durationNs
                 mainThreadBacktrace:(nullable NSString *)mainThreadBacktrace
                 allThreadsBacktrace:(nullable NSString *)allThreadsBacktrace
                   errorContextModel:(nullable FTFatalErrorContextModel *)errorContextModel;
- (nullable instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)convertToDictionary;
@end

@interface FTLongTaskANRDataStore : NSObject
@property (nonatomic, strong, readonly) dispatch_queue_t queue;
@property (nonatomic, readonly, getter=isClosed) BOOL closed;
@property (nonatomic, copy) NSString *dataStorePath;

- (void)deleteFile;
/// Reject late writes and enqueue cleanup without waiting for I/O.
- (void)shutDown;
- (void)writeANRData:(FTLongTaskANRData *)anrData;
/// Append a complete effective-duration/observation-time pair to this incident's snapshot.
- (void)appendTimingWithStartTimeNs:(long long)startTimeNs durationNs:(long long)durationNs endTimeNs:(long long)endTimeNs;
- (nullable FTLongTaskANRData *)readANRData;
@end

NS_ASSUME_NONNULL_END
