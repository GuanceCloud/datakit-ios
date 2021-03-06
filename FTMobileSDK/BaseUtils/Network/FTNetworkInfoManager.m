//
//  FTNetworkInfoManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/30.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTNetworkInfoManager.h"
@interface FTNetworkInfoManager()

@end
@implementation FTNetworkInfoManager
+ (instancetype)sharedInstance{
    static FTNetworkInfoManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (FTNetworkInfoManager *(^)(NSString *value))setMetricsUrl {
    return ^(NSString *value) {
        self->_metricsUrl = value;
        return self;
    };
}

- (FTNetworkInfoManager *(^)(NSString *value))setXDataKitUUID{
    return ^(NSString *value) {
        self->_XDataKitUUID = value;
        return self;
    };
}
- (FTNetworkInfoManager *(^)(NSString *value))setSdkVersion{
    return ^(NSString *value) {
        self->_sdkVersion = value;
        return self;
    };
}

@end
