//
//  FTMobileAgent.h
//  FTSDK
//
//  Created by hulilei on 2019/11/28.
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

#ifndef FTMobileAgent_h
#define FTMobileAgent_h

#import "FTMobileConfig.h"
#import "FTSDKAgent.h"

NS_ASSUME_NONNULL_BEGIN

/// Compatibility entry point for the legacy mobile agent API.
///
/// This class does not retain SDK business state. Calls are forwarded to
/// `FTSDKAgent`. New integrations should use `FTSDKAgent` directly.
@interface FTMobileAgent : NSObject

- (instancetype)init __attribute__((unavailable("Please use sharedInstance to access")));

+ (instancetype)sharedInstance;
+ (void)startWithConfigOptions:(FTSDKConfig *)configOptions;

- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions;
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions;
- (void)isIntakeUrl:(BOOL(^)(NSURL *url))handler DEPRECATED_MSG_ATTRIBUTE("Deprecated, please set `resourceUrlHandler` when configuring FTRumConfig as replacement");
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions;
- (void)logging:(NSString *)content status:(FTLogStatus)status;
- (void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property;

- (void)bindUserWithUserID:(NSString *)userId;
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail;
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail extra:(nullable NSDictionary *)extra;
- (void)unbindUser;

+ (void)appendGlobalContext:(NSDictionary<NSString *, id> *)context;
+ (void)appendRUMGlobalContext:(NSDictionary<NSString *, id> *)context;
+ (void)appendLogGlobalContext:(NSDictionary<NSString *, id> *)context;

- (void)trackEventFromExtensionWithGroupIdentifier:(NSString *)groupIdentifier
                                        completion:(nullable void (^)(NSString *groupIdentifier, NSArray *events))completion;
- (void)flushSyncData;

+ (void)shutDown;
+ (void)clearAllData;
+ (void)updateRemoteConfig;
+ (void)updateRemoteConfigWithMiniUpdateInterval:(NSInteger)miniUpdateInterval
                                      completion:(nullable FTRemoteConfigFetchCompletionBlock)completion;
+ (void)setDatakitURL:(NSString *)url;
+ (void)setDatawayURL:(NSString *)url clientToken:(NSString *)token;

+ (void)updateRemoteConfigWithMiniUpdateInterval:(int)miniUpdateInterval
                                        callback:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable config))callback
    DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -updateRemoteConfigWithMiniUpdateInterval:completion: instead");
- (void)logout DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -unbindUser instead");
- (void)shutDown DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use +shutDown instead");

@end

NS_ASSUME_NONNULL_END

#endif /* FTMobileAgent_h */
