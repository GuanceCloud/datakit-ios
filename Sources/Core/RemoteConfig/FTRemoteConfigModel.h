//
//  FTRemoteConfigModel.h
//
//  Created by hulilei on 2025/12/23.
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

NS_ASSUME_NONNULL_BEGIN

/// Remote configuration values fetched from the RUM environment variable service.
@interface FTRemoteConfigModel : NSObject

/// Application environment, such as `prod`, `gray`, `pre`, `common`, `local`, or a custom single-word environment.
@property (nonatomic, copy, nullable) NSString *env;
/// Business or service name applied to the `service` field in Log and RUM data.
@property (nonatomic, copy, nullable) NSString *serviceName;
/// Whether collected data should be synchronized automatically after collection.
@property (nonatomic, strong, nullable) NSNumber *autoSync;
/// Whether upload payloads should be compressed with deflate before intake requests are sent.
@property (nonatomic, strong, nullable) NSNumber *compressIntakeRequests;
/// Number of records included in each synchronization request.
@property (nonatomic, strong, nullable) NSNumber *syncPageSize;
/// Sleep interval, in milliseconds, between synchronization requests.
@property (nonatomic, strong, nullable) NSNumber *syncSleepTime;

/// RUM sample rate in the range `[0, 1]`, applied to View, Action, LongTask, and Error data in the same session.
@property (nonatomic, strong, nullable) NSNumber *rumSampleRate;
/// On-error RUM compensation sample rate used when a session was not selected by `rumSampleRate`.
@property (nonatomic, strong, nullable) NSNumber *rumSessionOnErrorSampleRate;
/// Whether native user actions should be automatically tracked.
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceUserAction;
/// Whether native views should be automatically tracked.
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceUserView;
/// Whether native resource requests should be automatically tracked.
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceUserResource;
/// Whether resource host IP collection is enabled.
@property (nonatomic, strong, nullable) NSNumber *rumEnableResourceHostIP;
/// Whether application UI-block or freeze monitoring is enabled.
@property (nonatomic, strong, nullable) NSNumber *rumEnableTrackAppUIBlock;
/// UI-block duration threshold in milliseconds.
@property (nonatomic, strong, nullable) NSNumber *rumBlockDurationMs;
/// Whether application crash tracking is enabled.
@property (nonatomic, strong, nullable) NSNumber *rumEnableTrackAppCrash;
/// Whether application ANR tracking is enabled.
@property (nonatomic, strong, nullable) NSNumber *rumEnableTrackAppANR;
/// Whether WebView RUM data monitoring is enabled.
@property (nonatomic, strong, nullable) NSNumber *rumEnableTraceWebView;
/// WebView host allowlist for data tracking; nil allows all hosts and an empty array allows none.
@property (nonatomic, copy, nullable) NSArray *rumAllowWebViewHost;

/// Trace sample rate in the range `[0, 1]`.
@property (nonatomic, strong, nullable) NSNumber *traceSampleRate;
/// Whether native network auto-tracing is enabled.
@property (nonatomic, strong, nullable) NSNumber *traceEnableAutoTrace;
/// Trace propagation type, such as `ddTrace`, `zipkinMultiHeader`, `zipkinSingleHeader`, `traceparent`, `skywalking`, or `jaeger`.
@property (nonatomic, copy, nullable) NSString *traceType;

/// Log sample rate in the range `[0, 1]`.
@property (nonatomic, strong, nullable) NSNumber *logSampleRate;
/// Log level filter list, such as `info` and `warn`.
@property (nonatomic, copy, nullable) NSArray *logLevelFilters;
/// Whether custom log upload is enabled.
@property (nonatomic, strong, nullable) NSNumber *logEnableCustomLog;
/// Whether Browser Logs SDK events from WebViews are collected.
@property (nonatomic, strong, nullable) NSNumber *logEnableWebViewLog;

/// Session Replay sample rate in the range `[0, 1]`.
@property (nonatomic, strong, nullable) NSNumber *sessionReplaySampleRate;
/// On-error Session Replay compensation sample rate used when a session was not selected by `sessionReplaySampleRate`.
@property (nonatomic, strong, nullable) NSNumber *sessionReplayOnErrorSampleRate;

@end

NS_ASSUME_NONNULL_END
