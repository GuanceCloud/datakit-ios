//
//  FTPresetProperty.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/10/23.
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
#import "FTDataModifier.h"
#import "FTInternalConstants.h"
#import "FTSDKCompat.h"
#import "FTReadWriteHelper.h"
NS_ASSUME_NONNULL_BEGIN
@class FTUserInfo;
/// Preset properties
@interface FTPresetProperty : NSObject

@property (nonatomic, strong, readonly) NSDictionary *sessionReplayTags;

/// Device name
+ (NSString *)deviceInfo;
+ (NSString *)getApplicationUUID;
+ (NSString *)cpuArch;
+ (NSString *)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode;
#if FT_HOST_MAC
+ (NSString *)getDeviceUUID;
+ (NSString *)macOSDeviceModel;
#endif
+ (NSString *)getOSVersion;
+ (instancetype)sharedInstance;
/// Initialization method
/// - Parameter version: Version number
/// - Parameter sdkVersion: SDK version number
/// - Parameter env: Environment
/// - Parameter service: Service
/// - Parameter globalContext: Global custom properties
- (void)startWithVersion:(NSString *)version sdkVersion:(NSString *)sdkVersion env:(NSString *)env service:(NSString *)service globalContext:(nullable NSDictionary *)globalContext pkgInfo:(nullable NSDictionary *)pkgInfo;

- (void)setDataModifier:(nullable FTDataModifier)dataModifier lineDataModifier:(nullable FTLineDataModifier)lineDataModifier;

- (void)setRUMAppID:(NSString *)appID sampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate rumGlobalContext:(nullable NSDictionary *)rumGlobalContext;

-(void)setLogGlobalContext:(nullable NSDictionary *)logGlobalContext;

- (NSDictionary *)rumTags;
- (NSDictionary *)rumDynamicTags;

- (NSDictionary *)loggerTags;
- (NSDictionary *)loggerDynamicTags;

-(void)setSessionReplaySource:(NSString *)sessionReplaySource;

- (void)appendGlobalContext:(NSDictionary *)context;

- (void)appendRUMGlobalContext:(NSDictionary *)context;

- (void)appendLogGlobalContext:(NSDictionary *)context;

- (NSDictionary *)applyModifier:(nullable NSDictionary *)dict;

- (nullable NSArray<NSDictionary *> *)applyLineModifier:(NSString *)measurement
                                          tags:(nullable NSDictionary *)tags
                                        fields:(nullable NSDictionary *)fields;

-(void)updateUser:(NSString *)Id name:(nullable NSString *)name email:(nullable NSString *)email extra:(nullable NSDictionary *)extra;

-(void)clearUser;

- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
