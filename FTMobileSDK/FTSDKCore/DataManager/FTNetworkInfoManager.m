//
//  FTNetworkInfoManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/30.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTNetworkInfoManager.h"
#import "FTInternalLog.h"
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

- (FTNetworkInfoManager *(^)(NSString *value))setDatakitUrl {
    return ^(NSString *value) {
        self->_datakitUrl = value;
        FTInnerLogInfo(@"SDK Datakit URL：%@",value);
        return self;
    };
}

- (FTNetworkInfoManager *(^)(NSString *value))setSdkVersion{
    return ^(NSString *value) {
        self->_sdkVersion = value;
        return self;
    };
}

- (nonnull FTNetworkInfoManager * _Nonnull (^)(NSString * _Nonnull __strong))setDatawayUrl {
    return ^(NSString *value) {
        self->_datawayUrl = value;
        FTInnerLogInfo(@"SDK Dataway URL：%@",value);
        return self;
    };
}


- (nonnull FTNetworkInfoManager * _Nonnull (^)(NSString * _Nonnull __strong))setClientoken {
    return ^(NSString *value) {
        self->_clientToken = value;
        FTInnerLogInfo(@"SDK Dataway Client Token：%@",value);
        return self;
    };
}

@end
