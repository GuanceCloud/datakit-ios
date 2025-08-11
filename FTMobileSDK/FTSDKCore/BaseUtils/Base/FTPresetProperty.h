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

@property (nonatomic, strong, readonly) NSDictionary *loggerTags;
@property (nonatomic, strong, readonly) NSDictionary *rumTags;
@property (nonatomic, strong, readonly) NSDictionary *rumStaticFields;

/// Set data modifier
@property (nonatomic, copy, nullable) FTLineDataModifier lineDataModifier;
/// Device name
+ (NSString *)deviceInfo;
+ (NSString *)cpuArch;
+ (NSString *)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode;
#if FT_MAC
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
- (void)startWithVersion:(NSString *)version sdkVersion:(NSString *)sdkVersion env:(NSString *)env service:(NSString *)service globalContext:(NSDictionary *)globalContext pkgInfo:(nullable NSDictionary *)pkgInfo;

- (void)setDataModifier:(FTDataModifier)dataModifier lineDataModifier:(FTLineDataModifier)lineDataModifier;

- (void)setRUMAppID:(NSString *)appID sampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate rumGlobalContext:(NSDictionary *)rumGlobalContext;

-(void)setLogGlobalContext:(NSDictionary *)logGlobalContext;

- (NSDictionary *)rumDynamicTags;

- (NSDictionary *)loggerDynamicTags;

- (void)appendGlobalContext:(NSDictionary *)context;

- (void)appendRUMGlobalContext:(NSDictionary *)context;

- (void)appendLogGlobalContext:(NSDictionary *)context;

- (NSArray<NSDictionary *> *)applyLineModifier:(NSString *)measurement
                                          tags:(NSDictionary *)tags
                                        fields:(NSDictionary *)fields;
-(void)updateUser:(NSString *)Id name:(nullable NSString *)name email:(nullable NSString *)email extra:(nullable NSDictionary *)extra;

-(void)clearUser;

- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
