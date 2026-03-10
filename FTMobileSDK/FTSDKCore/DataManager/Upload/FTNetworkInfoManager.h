//
//  FTNetworkInfoManager.h
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/30.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTInternalConstants.h"
typedef NS_ENUM(NSInteger, FTNetworkConfigState) {
    FTNetworkConfigStateNotConfigured = 0,
    FTNetworkConfigStateDatakitMode,
    FTNetworkConfigStateDatawayMode,
};
NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkInfoManager : NSObject
@property (nonatomic,copy,readonly) NSString *datakitUrl;
@property (nonatomic,copy,readonly) NSString *datawayUrl;
@property (nonatomic,copy,readonly) NSString *clientToken;
@property (nonatomic,copy,readonly) NSString *sdkVersion;
@property (nonatomic,copy,readonly) NSString *appId;
@property (nonatomic,assign,readonly) BOOL compression;
@property (nonatomic,assign,readonly) BOOL enableDataIntegerCompatible;
@property (nonatomic, assign) FTNetworkConfigState configState;


+ (instancetype)sharedInstance;

- (FTNetworkInfoManager *(^)(NSString * _Nullable datakitUrl,
                            NSString * _Nullable datawayUrl,
                             NSString * _Nullable clientToken))setUploadURL;
- (FTNetworkInfoManager *(^)(NSString *value))setSdkVersion;
- (FTNetworkInfoManager *(^)(NSString *value))setAppId;
- (FTNetworkInfoManager *(^)(BOOL value))setEnableDataIntegerCompatible;
- (FTNetworkInfoManager *(^)(BOOL value))setCompressionIntakeRequests;

- (BOOL)isNetworkConfigured;
@end

NS_ASSUME_NONNULL_END
