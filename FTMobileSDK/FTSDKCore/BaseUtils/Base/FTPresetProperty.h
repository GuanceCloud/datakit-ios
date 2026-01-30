//
//  FTPresetProperty.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/10/23.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTDataModifier.h"
#import "FTEnumConstant.h"
#import "FTSDKCompat.h"
#import "FTReadWriteHelper.h"
NS_ASSUME_NONNULL_BEGIN
@class FTUserInfo;
/// Preset properties
@interface FTPresetProperty : NSObject


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

- (void)appendGlobalContext:(NSDictionary *)context;

- (void)appendRUMGlobalContext:(NSDictionary *)context;

- (void)appendLogGlobalContext:(NSDictionary *)context;

- (nullable NSArray<NSDictionary *> *)applyLineModifier:(NSString *)measurement
                                          tags:(NSDictionary *)tags
                                        fields:(NSDictionary *)fields;
-(void)updateUser:(NSString *)Id name:(nullable NSString *)name email:(nullable NSString *)email extra:(nullable NSDictionary *)extra;

-(void)clearUser;

- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
