//
//  FTNetworkInfoManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/30.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTNetworkInfoManager.h"
#import "FTLog+Private.h"
#import "FTBaseInfoHandler.h"

@interface FTNetworkInfoManager()

@end
static dispatch_once_t onceToken;
static FTNetworkInfoManager *sharedInstance = nil;
@implementation FTNetworkInfoManager
+ (instancetype)sharedInstance{
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
- (FTNetworkInfoManager *(^)(NSString *value))setDatakitUrl {
    return ^(NSString *value) {
        self->_datakitUrl = value;
        if(value && value.length>0){
            FTInnerLogInfo(@"SDK Datakit URL：%@",value);
        }
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
        if(value && value.length>0){
            FTInnerLogInfo(@"SDK Dataway URL：%@",value);
        }
        return self;
    };
}


- (nonnull FTNetworkInfoManager * _Nonnull (^)(NSString * _Nonnull __strong))setClientToken {
    return ^(NSString *value) {
        self->_clientToken = value;
        if(value && value.length>0){
            FTInnerLogInfo(@"SDK Dataway Client Token：%@*****",[value substringWithRange:NSMakeRange(0, value.length/2)]);
        }
        return self;
    };
}
- (FTNetworkInfoManager *(^)(BOOL value))setEnableDataIntegerCompatible{
    return ^(BOOL value) {
        self->_enableDataIntegerCompatible = value;
        return self;
    };
}
- (FTNetworkInfoManager *(^)(BOOL value))setCompression{
    return ^(BOOL value) {
        self->_compression = value;
        FTInnerLogInfo(@"SDK compressIntakeRequests ：%@",value?@"true":@"false");
        return self;
    };
}
- (FTNetworkInfoManager *(^)(NSString *value))setAppId{
    return ^(NSString *value) {
        self->_appId = value;
        return self;
    };
}
+ (void)shutDown{
    if(sharedInstance){
        onceToken = 0;
        sharedInstance = nil;
    }
}
@end
