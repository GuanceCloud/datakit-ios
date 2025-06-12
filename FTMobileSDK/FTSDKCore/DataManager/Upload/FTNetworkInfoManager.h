//
//  FTNetworkInfoManager.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/30.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTEnumConstant.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkInfoManager : NSObject
@property (nonatomic,copy,readonly) NSString *datakitUrl;
@property (nonatomic,copy,readonly) NSString *datawayUrl;
@property (nonatomic,copy,readonly) NSString *clientToken;
@property (nonatomic,copy,readonly) NSString *sdkVersion;
@property (nonatomic,copy,readonly) NSString *appId;
// 仅 compression 有多线程读写操作，其余属性仅在 SDK 初始化时赋值
@property (atomic,assign,readonly) BOOL compression;
@property (nonatomic,assign,readonly) BOOL enableDataIntegerCompatible;

+ (instancetype)sharedInstance;
- (FTNetworkInfoManager *(^)(NSString *value))setDatakitUrl;
- (FTNetworkInfoManager *(^)(NSString *value))setDatawayUrl;
- (FTNetworkInfoManager *(^)(NSString *value))setClientToken;
- (FTNetworkInfoManager *(^)(NSString *value))setSdkVersion;
- (FTNetworkInfoManager *(^)(NSString *value))setAppId;
- (FTNetworkInfoManager *(^)(BOOL value))setEnableDataIntegerCompatible;
- (FTNetworkInfoManager *(^)(BOOL value))setCompressionIntakeRequests;
+ (void)shutDown;
@end

NS_ASSUME_NONNULL_END
