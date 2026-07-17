//
//  FTRemoteConfigError.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/12/24.
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

#import "FTRemoteConfigError.h"

NSString *const FTRemoteConfigErrorDomain = @"com.ft.remoteConfigErrorDomain";

static NSDictionary<NSNumber *, NSString *> *defaultErrorDescriptions(void) {
    static NSDictionary *descriptions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        descriptions = @{
            @(FTRemoteConfigErrorCodeDisabled): @"Remote config is disabled.",
            @(FTRemoteConfigErrorCodeIntervalNotMet): @"Update interval not met.",
            @(FTRemoteConfigErrorCodeRequesting): @"A remote config request is already in progress. Please try again later.",
            @(FTRemoteConfigErrorCodeNetworkFailed): @"Network request failed to fetch remote configuration.",
            @(FTRemoteConfigErrorCodeParseFailed): @"Failed to parse remote configuration data. Invalid config format.",
            @(FTRemoteConfigErrorCodeSDKNotInitialized): @"SDK is not initialized. Please call the initialization method first.",
            @(FTRemoteConfigErrorCodeSyncConfigMissing): @"Sync URL or AppID is not configured."
        };
    });
    return descriptions;
}

@implementation FTRemoteConfigError

+ (NSError *)errorWithDisabled {
    return [self errorWithCode:FTRemoteConfigErrorCodeDisabled customDescription:nil];
}

+ (NSError *)errorWithIntervalNotMet:(NSString *)tipMessage {
    NSString *description = [NSString stringWithFormat:@"%@ %@",
                             defaultErrorDescriptions()[@(FTRemoteConfigErrorCodeIntervalNotMet)],
                             tipMessage];
    return [self errorWithCode:FTRemoteConfigErrorCodeIntervalNotMet customDescription:description];
}

+ (NSError *)errorWithRequesting {
    return [self errorWithCode:FTRemoteConfigErrorCodeRequesting customDescription:nil];
}

+ (NSError *)errorWithNetworkFailed:(nullable NSError *)underlyingError {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = defaultErrorDescriptions()[@(FTRemoteConfigErrorCodeNetworkFailed)];

    if (underlyingError) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    return [NSError errorWithDomain:FTRemoteConfigErrorDomain
                               code:FTRemoteConfigErrorCodeNetworkFailed
                           userInfo:userInfo];
}

+ (NSError *)errorWithParseFailed:(nullable NSString *)reason {
    NSString *description = defaultErrorDescriptions()[@(FTRemoteConfigErrorCodeParseFailed)];
    if (reason) {
        description = [NSString stringWithFormat:@"%@ Reason: %@", description, reason];
    }
    return [self errorWithCode:FTRemoteConfigErrorCodeParseFailed customDescription:description];
}

+ (NSError *)errorWithSDKNotInitialized {
    return [self errorWithCode:FTRemoteConfigErrorCodeSDKNotInitialized customDescription:nil];
}

+ (NSError *)errorWithCode:(FTRemoteConfigErrorCode)code customDescription:(nullable NSString *)description {
    NSString *defaultDesc = defaultErrorDescriptions()[@(code)] ?: @"Unknown remote configuration error.";
    NSString *finalDesc = description ?: defaultDesc;
    
    return [NSError errorWithDomain:FTRemoteConfigErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: finalDesc,
                                      NSLocalizedFailureReasonErrorKey: finalDesc}];
}

@end
