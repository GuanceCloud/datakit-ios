//
//  FTNetworkInfoManager.h
//  FTSDK
//
//  Created by hulilei on 2021/8/30.
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

- (BOOL)isNetworkConfiguredForRemote;

- (void)clearUploadInfo;
@end

NS_ASSUME_NONNULL_END
