//
//  FTNetworkInfoManager.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/30.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkInfoManager : NSObject
@property (nonatomic,copy,readonly) NSString *datakitUrl;
@property (nonatomic,copy,readonly) NSString *datawayUrl;
@property (nonatomic,copy,readonly) NSString *clientToken;
@property (nonatomic,copy,readonly) NSString *sdkVersion;

+ (instancetype)sharedInstance;
- (FTNetworkInfoManager *(^)(NSString *value))setDatakitUrl;
- (FTNetworkInfoManager *(^)(NSString *value))setDatawayUrl;
- (FTNetworkInfoManager *(^)(NSString *value))setClientToken;
- (FTNetworkInfoManager *(^)(NSString *value))setSdkVersion;

@end

NS_ASSUME_NONNULL_END
