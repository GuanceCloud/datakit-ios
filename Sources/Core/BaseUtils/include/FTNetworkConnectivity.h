//
//  FTNetworkConnectivity.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/18.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTNetworkChangeObserver <NSObject>
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)typeDescription;
@end
@interface FTNetworkConnectivity : NSObject
@property (nonatomic, assign, readonly) BOOL isConnected;
@property (atomic, copy, readonly) NSString *networkType;

+ (instancetype)sharedInstance;

/// Latest path link quality: unknown=0, minimal=1, moderate=2, good=3.
/// Supported on iOS/tvOS/macOS 26.0+ when built with a supporting SDK.
/// Returns nil before the first path update or on systems/SDKs without support.
/// This ordinal value does not represent RSSI, dBm, or signal bars.
- (nullable NSNumber *)networkSignalStrength;

- (NSDictionary<NSString *, id> *)networkResourceFields;

- (void)addNetworkObserver:(id<FTNetworkChangeObserver>)observer;

- (void)removeNetworkObserver:(id<FTNetworkChangeObserver>)observer;
/// Enqueues monitoring startup. Network fields remain unset until the first path update.
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
