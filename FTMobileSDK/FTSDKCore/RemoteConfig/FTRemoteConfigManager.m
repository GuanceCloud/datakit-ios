//
//  FTRemoteConfigManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/5.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRemoteConfigManager.h"
#import "FTHTTPClient.h"
#import "FTTrackDataManager.h"
#import "FTRemoteConfigurationRequest.h"
#import "FTJSONUtil.h"
#import "FTLog+Private.h"
#import "FTNetworkInfoManager.h"
@interface FTRemoteConfigManager()
@property (atomic, assign) BOOL isFetching;
@property (atomic, assign) NSTimeInterval lastRequestTimeInterval;
@property (nonatomic, assign) BOOL enable;
@property (nonatomic, assign) int updateInterval;
@property (nonatomic, strong) NSDictionary *localRemoteConfiguration;
@end

@implementation FTRemoteConfigManager
+ (instancetype)sharedManager{
    static FTRemoteConfigManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[FTRemoteConfigManager alloc] init];
    });
    return sharedManager;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        _isFetching = NO;
        _enable = NO;
    }
    return self;
}
- (void)enable:(BOOL)enable updateInterval:(int)updateInterval{
    _enable = enable;
    _updateInterval = updateInterval;
}
- (void)updateRemoteConfig{
    [self updateRemoteConfigWithMiniUpdateInterval:self.updateInterval callback:nil];
}
- (void)updateRemoteConfigWithMiniUpdateInterval:(int)miniUpdateInterval callback:(void (^)(BOOL, NSDictionary<NSString *,id> * _Nullable))callback{
    if (!self.enable) {
        FTInnerLogInfo(@"[remote-config] Disable remote configuration.");
        return;
    }
    if (self.isFetching) {
        FTInnerLogInfo(@"[remote-config] Request is being processed.");
        if(callback)callback(NO,nil);
        return;
    }
    if (self.lastRequestTimeInterval > 0 && miniUpdateInterval > 0 && [[NSDate date] timeIntervalSince1970] - self.lastRequestTimeInterval > miniUpdateInterval) {
        FTInnerLogInfo(@"[remote-config] The time interval between last request is shorter than mini Update Interval.");
        if(callback)callback(NO,nil);
        return;
    }
    [self requestRemoteConfigWithCompletion:callback];
}
- (void)requestRemoteConfigWithCompletion:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable config))completion{
    self.isFetching = YES;
    FTRemoteConfigurationRequest *request = [[FTRemoteConfigurationRequest alloc]init];
    __weak typeof(self) weakSelf = self;
    [[FTTrackDataManager sharedInstance].httpClient sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSInteger statusCode = httpResponse.statusCode;
        BOOL success = statusCode == 200;
        NSDictionary<NSString *, id> *config = nil;
        if (success && data.length) {
            config = [FTJSONUtil dictionaryWithJsonString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
            [strongSelf handleRemoteConfig:config[@"content"]];
            strongSelf.lastRequestTimeInterval = [[NSDate date] timeIntervalSince1970];
        }
        if (completion) {
            completion(success,config);
        }
        strongSelf.isFetching = NO;
    }];
}
//- (void)cancelRequestRemoteConfig {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        // 还未发出请求
//        [NSObject cancelPreviousPerformRequestsWithTarget:self];
//    });
//}
- (void)handleRemoteConfig:(NSDictionary<NSString *, id> *)remoteConfig {
    @try {
        if ([remoteConfig isKindOfClass:[NSDictionary class]] && ([remoteConfig count] > 0)) {
            NSDictionary *realRemoteConfig = [self removingPrefix:remoteConfig];
            if ([realRemoteConfig isEqual:self.localRemoteConfiguration]) {
                return;
            }
            if (self.delegate && [self.delegate respondsToSelector:@selector(updateRemoteConfiguration:)]) {
                [self.delegate updateRemoteConfiguration:realRemoteConfig];
            }
            [self saveRemoteConfig:realRemoteConfig];
        }else{
            [self saveRemoteConfig:nil];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
- (NSDictionary *)removingPrefix:(NSDictionary *)context {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSString *prefixToRemove = [NSString stringWithFormat:@"R.%@.",[FTNetworkInfoManager sharedInstance].appId];
    [context enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key hasPrefix:prefixToRemove]) {
            NSString *newKey = [key substringFromIndex:prefixToRemove.length];
            result[newKey] = obj;
        } else {
            result[key] = obj;
        }
    }];
    return [result copy];
}
- (NSDictionary *)getLocalRemoteConfig{
    if (!self.enable) {
        return nil;
    }
    if (self.localRemoteConfiguration) {
        return self.localRemoteConfiguration;
    }
    NSDictionary *local = [[NSUserDefaults standardUserDefaults] objectForKey:@"FT_REMOTE_CONFIG"];
    self.localRemoteConfiguration = local;
    return local;
}
- (void)saveRemoteConfig:(NSDictionary<NSString *, id> *)remoteConfig{
    self.localRemoteConfiguration = remoteConfig;
    [[NSUserDefaults standardUserDefaults] setObject:remoteConfig forKey:@"FT_REMOTE_CONFIG"];
    FTInnerLogInfo(@"[remote-config] Update Remote Config: %@",remoteConfig);
}
@end
