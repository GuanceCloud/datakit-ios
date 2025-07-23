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
        _concurrentQueue = dispatch_queue_create("com.guance.network.info", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}
- (FTNetworkInfoManager *(^)(NSString *value))setDatakitUrl {
    return ^(NSString *value) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.datakitUrl = value;
        });
        if(value && value.length>0){
            FTInnerLogInfo(@"SDK Datakit URL：%@",value);
        }
        return self;
    };
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
- (nonnull FTNetworkInfoManager * _Nonnull (^)(NSString * _Nonnull __strong))setDatawayUrl {
    return ^(NSString *value) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.datawayUrl = value;
        });
        if(value && value.length>0){
            FTInnerLogInfo(@"SDK Dataway URL：%@",value);
        }
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
- (nonnull FTNetworkInfoManager * _Nonnull (^)(NSString * _Nonnull __strong))setClientToken {
    return ^(NSString *value) {
        dispatch_barrier_async(self.concurrentQueue, ^{
            self.clientToken = value;
        });
        if(value && value.length>0){
            FTInnerLogInfo(@"SDK Dataway Client Token：%@*****",[value substringWithRange:NSMakeRange(0, value.length/2)]);
        }
        return self;
    };
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
@end
