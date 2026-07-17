//
//  FTCrashMonitor.h
//
//  Created by hulilei on 2020/1/6.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTCrashMonitorType.h"
#import "FTErrorDataProtocol.h"
#import "FTRUMDataWriteProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// Crash collection tool
@interface FTCrash : NSObject


@property (nonatomic, readwrite, assign) FTCrashCMonitorType monitoring;


@property (nonatomic, readonly, strong) id<FTBacktraceReporting> backtraceReporting;


@property(atomic, readwrite, copy, nullable) NSDictionary<NSString *, id> *userInfo;

/** The maximum number of reports allowed on disk before old ones get deleted.
 *
 * Default: 1
 */
@property (nonatomic, readwrite, assign) int maxReportCount;

/// When enabled, the SDK reports SIGTERM signals to Sentry.
///
/// It's crucial for developers to understand that the OS sends a SIGTERM to their app as a prelude
/// to a graceful shutdown, before resorting to a SIGKILL. This SIGKILL, which your app can't catch
/// or ignore, is a direct order to terminate your app's process immediately. Developers should be
/// aware that their app can receive a SIGTERM in various scenarios, such as  CPU or disk overuse,
/// watchdog terminations, or when the OS updates your app.
///
/// @note The default value is NO.
@property (nonatomic, readwrite, assign) BOOL enableSigtermReporting;

/** If true, the application crashed on the previous launch. */
@property(nonatomic, readonly, assign) BOOL crashedLastLaunch;

/** If value > 0, the application crashed on the previous launch. */
@property(nonatomic, readonly, assign) double crashedLastTimestamp;

/// Singleton
+ (instancetype)shared;

+ (void)setupWithMonitoringType:(FTCrashCMonitorType)monitoring
                    writer:(id<FTRUMDataWriteProtocol>)writer
       enableMonitorMemory:(BOOL)memory
          enableMonitorCpu:(BOOL)cpu;

@end

NS_ASSUME_NONNULL_END
