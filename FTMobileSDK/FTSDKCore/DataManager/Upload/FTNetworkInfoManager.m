//
//  FTNetworkInfoManager.m
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/30.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTNetworkInfoManager.h"
#import "FTLog+Private.h"
#import "FTBaseInfoHandler.h"

@interface FTNetworkInfoManager()
@property (nonatomic,copy,readwrite) NSString *datakitUrl;
@property (nonatomic,copy,readwrite) NSString *datawayUrl;
@property (nonatomic,copy,readwrite) NSString *clientToken;
@property (nonatomic,copy,readwrite) NSString *sdkVersion;
@property (nonatomic,copy,readwrite) NSString *appId;
@property (nonatomic,assign,readwrite) BOOL compression;
@property (nonatomic,assign,readwrite) BOOL enableDataIntegerCompatible;
@property (nonatomic,strong) dispatch_queue_t concurrentQueue;
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
-(instancetype)init{
    self = [super init];
    if (self) {
        _concurrentQueue = dispatch_queue_create("com.ft.network.info", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}
-(NSString *)datakitUrl{
    __block NSString *obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = [_datakitUrl copy];
    });
    return obj;
}

-(NSString *)sdkVersion{
    __block NSString *obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = [_sdkVersion copy];
    });
    return obj;
}
- (FTNetworkInfoManager *(^)(NSString *value))setSdkVersion{
    return ^(NSString *value) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.sdkVersion = value;
        });
        return self;
    };
}
-(NSString *)datawayUrl{
    __block NSString *obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = [_datawayUrl copy];
    });
    return obj;
}
- (FTNetworkInfoManager *(^)(NSString * _Nullable datakitUrl,
                            NSString * _Nullable datawayUrl,
                             NSString * _Nullable clientToken))setUploadURL{
    return ^(NSString * _Nullable datakitUrl,
             NSString * _Nullable datawayUrl,
              NSString * _Nullable clientToken) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.datakitUrl = datakitUrl;
            self.datawayUrl = datawayUrl;
            self.clientToken = clientToken;
            if (datakitUrl.length > 0) {
                // Datakit
                self.datakitUrl = datakitUrl;
                self.configState = FTNetworkConfigStateDatakitMode;
                FTInnerLogInfo(@"[NetworkInfo] SDK Datakit URL：%@", datakitUrl);
            } else if (datawayUrl.length > 0 && clientToken.length > 0) {
                // Dataway
                self.datawayUrl = datawayUrl;
                self.clientToken = clientToken;
                self.configState = FTNetworkConfigStateDatawayMode;
                FTInnerLogInfo(@"[NetworkInfo] SDK Dataway URL：%@", datawayUrl);
                FTInnerLogInfo(@"[NetworkInfo] SDK Dataway Client Token：%@",
                               clientToken.length>0?[NSString stringWithFormat:@"*****%@",[clientToken substringFromIndex:clientToken.length/2]]:nil);
            } else {
                self.configState = FTNetworkConfigStateNotConfigured;
                FTInnerLogWarning(@"[NetworkInfo] Invalid upload URL configuration");
            }
            
        });
        return self;
    };
}
-(NSString *)clientToken{
    __block NSString *obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = [_clientToken copy];
    });
    return obj;
}

-(BOOL)enableDataIntegerCompatible{
    __block BOOL obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = _enableDataIntegerCompatible;
    });
    return obj;
}
- (FTNetworkInfoManager *(^)(BOOL value))setEnableDataIntegerCompatible{
    return ^(BOOL value) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.enableDataIntegerCompatible = value;
        });
        return self;
    };
}
-(BOOL)compression{
    __block BOOL obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = _compression;
    });
    return obj;
}
- (FTNetworkInfoManager *(^)(BOOL value))setCompressionIntakeRequests{
    return ^(BOOL value) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.compression = value;
        });
        FTInnerLogInfo(@"SDK compressIntakeRequests ：%@",value?@"true":@"false");
        return self;
    };
}
-(NSString *)appId{
    __block NSString *obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = [_appId copy];
    });
    return obj;
}
- (FTNetworkInfoManager *(^)(NSString *value))setAppId{
    return ^(NSString *value) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.appId = value;
        });
        return self;
    };
}
-(FTNetworkConfigState)configState{
    __block FTNetworkConfigState obj;
    dispatch_sync(_concurrentQueue, ^{
        obj = _configState;
    });
    return obj;
}
- (BOOL)isNetworkConfigured {
    return self.configState != FTNetworkConfigStateNotConfigured;
}
- (BOOL)isNetworkConfiguredForRemote {
    return [self isNetworkConfigured] && self.appId != nil;
}
- (void)clearUploadInfo{
    dispatch_barrier_async(self.concurrentQueue, ^{
        self.datakitUrl = nil;
        self.datawayUrl = nil;
        self.clientToken = nil;
        self.appId = nil;
        self.configState = FTNetworkConfigStateNotConfigured;
    });
}
@end
