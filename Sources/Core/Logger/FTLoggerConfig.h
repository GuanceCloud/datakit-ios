//
//  FTLoggerConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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
/// Event level and status, default: FTStatusInfo
typedef NS_ENUM(NSInteger, FTLogStatus) {
    /// Info
    FTStatusInfo         = 0,
    /// Warning
    FTStatusWarning,
    /// Error
    FTStatusError,
    /// Critical
    FTStatusCritical,
    /// Ok
    FTStatusOk,
};
/// Log discard strategy
typedef NS_ENUM(NSInteger, FTLogCacheDiscard)  {
    /// Default, when log data count exceeds maximum (5000), new data is not written
    FTDiscard,
    /// When log data exceeds maximum, discard old data
    FTDiscardOldest
};
NS_ASSUME_NONNULL_BEGIN
/// Logger feature configuration options
@interface FTLoggerConfig : NSObject
/// Disable new initialization
+ (instancetype)new NS_UNAVAILABLE;
/// Log discard strategy
@property (nonatomic, assign) FTLogCacheDiscard  discardType;
/// Sampling configuration, property values: 0 to 100, 100 means 100% collection, no data sample compression.
@property (nonatomic, assign) int sampleRate;
/// Deprecated. Use `sampleRate`.
@property (nonatomic, assign) int samplerate DEPRECATED_MSG_ATTRIBUTE("Use sampleRate.");
/// Whether to associate logger data with rum
@property (nonatomic, assign) BOOL enableLinkRumData;
/// Whether to upload custom logs
@property (nonatomic, assign) BOOL enableCustomLog;
/// Whether to print custom logs to console
@property (nonatomic, assign) BOOL printCustomLogToConsole;
/// Log maximum cache size, minimum setting 1000, default 5000
@property (nonatomic, assign) int logCacheLimitCount;
/// Set log levels to collect, default is to collect all
///
/// Example: 1. To collect custom logs with log levels Info and Error, set to
/// @[@(FTStatusInfo),@(FTStatusError)] or @[@0,@1]
/// 2. To collect log levels including custom levels, such as collecting "customLevel" and FTStatusError, set to
/// @[@"customLevel",@(FTStatusError)]
@property (nonatomic, copy) NSArray *logLevelFilter;
/// Logger global tag
@property (nonatomic, copy) NSDictionary<NSString*,NSString*> *globalContext;
@end

NS_ASSUME_NONNULL_END
