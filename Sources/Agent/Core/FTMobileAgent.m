//
//  FTMobileAgent.m
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

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "FTMobileAgent.h"
#import "FTMobileAgent+Private.h"

@interface FTSDKAgent (LegacyForwarding)
+ (NSString *)sdkVersion;
@end

@interface FTMobileAgent ()
- (instancetype)initCompatibilityProxy;
@end

@implementation FTMobileAgent

static FTMobileAgent *compatibilityProxy;

- (instancetype)initCompatibilityProxy {
    return [super init];
}

+ (instancetype)sharedInstance {
    // Preserve the original precondition: the SDK must be started first.
    [FTSDKAgent sharedInstance];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        compatibilityProxy = [[FTMobileAgent alloc] initCompatibilityProxy];
    });
    return compatibilityProxy;
}

+ (void)startWithConfigOptions:(FTSDKConfig *)configOptions {
    [FTSDKAgent startWithConfigOptions:configOptions];
}

- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions {
    [[FTSDKAgent sharedInstance] startRumWithConfigOptions:rumConfigOptions];
}

- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions {
    [[FTSDKAgent sharedInstance] startLoggerWithConfigOptions:loggerConfigOptions];
}

- (void)isIntakeUrl:(BOOL (^)(NSURL *))handler {
    [[FTSDKAgent sharedInstance] isIntakeUrl:handler];
}

- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions {
    [[FTSDKAgent sharedInstance] startTraceWithConfigOptions:traceConfigOptions];
}

- (void)logging:(NSString *)content status:(FTLogStatus)status {
    [[FTSDKAgent sharedInstance] logging:content status:status];
}

- (void)logging:(NSString *)content status:(FTLogStatus)status property:(NSDictionary *)property {
    [[FTSDKAgent sharedInstance] logging:content status:status property:property];
}

- (void)bindUserWithUserID:(NSString *)userId {
    [[FTSDKAgent sharedInstance] bindUserWithUserID:userId];
}

- (void)bindUserWithUserID:(NSString *)userId
                  userName:(NSString *)userName
                 userEmail:(NSString *)userEmail {
    [[FTSDKAgent sharedInstance] bindUserWithUserID:userId userName:userName userEmail:userEmail];
}

- (void)bindUserWithUserID:(NSString *)userId
                  userName:(NSString *)userName
                 userEmail:(NSString *)userEmail
                     extra:(NSDictionary *)extra {
    [[FTSDKAgent sharedInstance] bindUserWithUserID:userId userName:userName userEmail:userEmail extra:extra];
}

- (void)unbindUser {
    [[FTSDKAgent sharedInstance] unbindUser];
}

+ (void)appendGlobalContext:(NSDictionary<NSString *,id> *)context {
    [FTSDKAgent appendGlobalContext:context];
}

+ (void)appendRUMGlobalContext:(NSDictionary<NSString *,id> *)context {
    [FTSDKAgent appendRUMGlobalContext:context];
}

+ (void)appendLogGlobalContext:(NSDictionary<NSString *,id> *)context {
    [FTSDKAgent appendLogGlobalContext:context];
}

- (void)trackEventFromExtensionWithGroupIdentifier:(NSString *)groupIdentifier
                                        completion:(void (^)(NSString *, NSArray *))completion {
    [[FTSDKAgent sharedInstance] trackEventFromExtensionWithGroupIdentifier:groupIdentifier completion:completion];
}

- (void)flushSyncData {
    [[FTSDKAgent sharedInstance] flushSyncData];
}

+ (void)shutDown {
    [FTSDKAgent shutDown];
}

+ (void)clearAllData {
    [FTSDKAgent clearAllData];
}

+ (void)updateRemoteConfig {
    [FTSDKAgent updateRemoteConfig];
}

+ (void)updateRemoteConfigWithMiniUpdateInterval:(NSInteger)miniUpdateInterval
                                      completion:(FTRemoteConfigFetchCompletionBlock)completion {
    [FTSDKAgent updateRemoteConfigWithMiniUpdateInterval:miniUpdateInterval completion:completion];
}

+ (void)setDatakitURL:(NSString *)url {
    [FTSDKAgent setDatakitURL:url];
}

+ (void)setDatawayURL:(NSString *)url clientToken:(NSString *)token {
    [FTSDKAgent setDatawayURL:url clientToken:token];
}

+ (void)updateRemoteConfigWithMiniUpdateInterval:(int)miniUpdateInterval
                                        callback:(void (^)(BOOL, NSDictionary<NSString *,id> * _Nullable))callback {
    [FTSDKAgent updateRemoteConfigWithMiniUpdateInterval:miniUpdateInterval
                                              completion:^(BOOL success,
                                                           NSError *error,
                                                           FTRemoteConfigModel *model,
                                                           NSDictionary<NSString *,id> *content) {
        if (callback) {
            callback(success, content);
        }
        return model;
    }];
}

- (void)logout {
    [[FTSDKAgent sharedInstance] unbindUser];
}

- (void)shutDown {
    [FTSDKAgent shutDown];
}

- (void)syncProcess {
    [[FTSDKAgent sharedInstance] syncProcess];
}

- (void)additionalConfigurationWithSource:(NSString *)source {
    [[FTSDKAgent sharedInstance] additionalConfigurationWithSource:source];
}

+ (NSString *)sdkVersion {
    return [FTSDKAgent sdkVersion];
}

@end
