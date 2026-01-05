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
#import "FTAppLifeCycle.h"
#import "FTRemoteConfigModel+Private.h"
#import "NSString+FTAdd.h"
#import "FTRemoteConfigError.h"

@interface FTRemoteConfigManager()<FTAppLifeCycleDelegate>
@property (atomic, assign) BOOL isFetching;
@property (atomic, assign) NSTimeInterval lastRequestTimeInterval;
@property (nonatomic, assign) BOOL enable;
@property (nonatomic, assign) int updateInterval;
@property (nonatomic, strong) FTRemoteConfigModel *lastRemoteModel;
@property (nonatomic, copy) FTRemoteConfigFetchCompletionBlock fetchCompletionBlock;
@end

@implementation FTRemoteConfigManager
@synthesize lastRemoteModel = _lastRemoteModel;

static FTRemoteConfigManager *sharedManager = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance{
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
- (void)setLastRemoteModel:(FTRemoteConfigModel *)lastRemoteModel{
    @synchronized (self) {
        _lastRemoteModel = lastRemoteModel;
    }
}
-(FTRemoteConfigModel *)lastRemoteModel{
    @synchronized (self) {
        return [_lastRemoteModel copy];
    }
}

- (void)enable:(BOOL)enable updateInterval:(int)updateInterval remoteConfigFetchCompletionBlock:(FTRemoteConfigFetchCompletionBlock)fetchCompletionBlock{
    _enable = enable;
    _updateInterval = updateInterval;
    self.fetchCompletionBlock = fetchCompletionBlock;
    if (enable) {
        self.lastRemoteModel = [[FTRemoteConfigModel alloc]initWithDict:[self getLastFetchedRemoteConfig]];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
}

- (void)updateRemoteConfig{
    [self updateRemoteConfigWithMinimumUpdateInterval:self.updateInterval completion:nil];
}
- (void)updateRemoteConfigWithMinimumUpdateInterval:(NSInteger)minimumUpdateInterval
                                         completion:(FTRemoteConfigFetchCompletionBlock)completion{
    if (!self.enable) {
        FTInnerLogInfo(@"[remote-config] Disable remote configuration.");
        if(completion)completion(NO,[FTRemoteConfigError errorWithDisabled],nil,nil);
        return;
    }
    if (self.lastRequestTimeInterval > 0 && minimumUpdateInterval > 0 && [[NSDate date] timeIntervalSince1970] - self.lastRequestTimeInterval < minimumUpdateInterval) {
        FTInnerLogInfo(@"[remote-config] The time interval between last request is shorter than mini Update Interval.");
        if(completion)completion(NO,[FTRemoteConfigError errorWithIntervalNotMet:minimumUpdateInterval],nil,nil);
        return;
    }
    if (self.isFetching) {
        FTInnerLogInfo(@"[remote-config] Request is being processed.");
        if(completion)completion(NO,[FTRemoteConfigError errorWithRequesting],nil,nil);
        return;
    }
    FTRemoteConfigFetchCompletionBlock completionBlock = completion;
    if (!completionBlock) {
        completionBlock = self.fetchCompletionBlock;
    }
    [self requestRemoteConfigWithCompletion:completionBlock];
}

- (void)requestRemoteConfigWithCompletion:(FTRemoteConfigFetchCompletionBlock)completion{
    FTInnerLogInfo(@"[remote-config] Start loading remote configuration.");
    self.isFetching = YES;
    FTRemoteConfigurationRequest *request = [[FTRemoteConfigurationRequest alloc]init];
    __weak typeof(self) weakSelf = self;
    [[FTTrackDataManager sharedInstance].httpClient sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                NSError *releaseError = [FTRemoteConfigError errorWithCode:FTRemoteConfigErrorCodeNetworkFailed
                                                         customDescription:@"Remote config manager instance released during request"];
                completion(NO, releaseError, nil, nil);
            }
            return;
        }
        BOOL success = NO;
        NSError *requestError = nil;
        FTRemoteConfigModel *model = nil;
        NSDictionary *content = nil;
        if (error) {
            requestError = [FTRemoteConfigError errorWithNetworkFailed:error];
            FTInnerLogError(@"[remote-config] Network request failed: %@", error.localizedDescription);
        } else if (httpResponse.statusCode != 200) {
            NSString *desc = [NSString stringWithFormat:@"Invalid HTTP status code: %ld (expected 200)", (long)httpResponse.statusCode];
            requestError = [FTRemoteConfigError errorWithCode:FTRemoteConfigErrorCodeNetworkFailed
                                            customDescription:desc];
            FTInnerLogError(@"[remote-config] Invalid status code: %ld", (long)httpResponse.statusCode);
        } else if (!data || data.length == 0) {
            requestError = [FTRemoteConfigError errorWithParseFailed:@"Empty response data from remote config server"];
            FTInnerLogError(@"[remote-config] Empty response data");
        } else {
            success = YES;
            model = [strongSelf handleRemoteConfigData:data];
            strongSelf.lastRequestTimeInterval = [[NSDate date] timeIntervalSince1970];
            content = model.context;
        }
        if (completion) {
           FTRemoteConfigModel *finalModel = completion(success, requestError, [model copy], [content copy]);
            if (finalModel) {
                model = [finalModel copy];
            }
        }
        if (success) {
            strongSelf.lastRemoteModel = model;
            if (model) {
                if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(remoteConfigurationDidChange)]) {
                    [strongSelf.delegate remoteConfigurationDidChange];
                }
                [strongSelf saveRemoteConfig:[model toDictionary]];
                FTInnerLogInfo(@"[remote-config] Remote config parsed successfully");
            } else {
                [strongSelf saveRemoteConfig:nil];
                FTInnerLogWarning(@"[remote-config] Remote config parsed to nil");
            }
        }
        strongSelf.isFetching = NO;
        FTInnerLogInfo(@"[remote-config] Complete the loading of the remote configuration.");
    }];
}
- (FTRemoteConfigModel *)handleRemoteConfigData:(NSData *)data {
    FTRemoteConfigModel *model = self.lastRemoteModel;
    @try {
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *md5 = [str ft_md5HashToLower16Bit];
        if (model && [md5 isEqualToString:model.md5Str]) {
            return model;
        }
        NSDictionary *remoteConfig = [FTJSONUtil dictionaryWithJsonString:[self removePrefixInString:str]];
        model = [[FTRemoteConfigModel alloc]initWithDict:remoteConfig[@"content"] md5:md5];
        
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    return model;
}

- (NSString *)removePrefixInString:(NSString *)jsonString {
    if (!jsonString || jsonString.length == 0) return jsonString;
    NSString *appId = [FTNetworkInfoManager sharedInstance].appId;
    NSString *pattern = [NSString stringWithFormat:@"\"R\\.%@\\.(.*?)\":", appId];
    NSString *replacedJson = [jsonString stringByReplacingOccurrencesOfString:pattern
                                                                     withString:@"\"$1\":"
                                                                        options:NSRegularExpressionSearch
                                                                          range:NSMakeRange(0, jsonString.length)];
    return replacedJson;
}
- (NSDictionary *)getLastFetchedRemoteConfig{
    if (!self.enable) {
        return nil;
    }
    NSDictionary *local = [[NSUserDefaults standardUserDefaults] objectForKey:@"FT_REMOTE_CONFIG"];
    return local;
}
- (void)saveRemoteConfig:(NSDictionary<NSString *, id> *)remoteConfig{
    [[NSUserDefaults standardUserDefaults] setObject:remoteConfig forKey:@"FT_REMOTE_CONFIG"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void)applicationDidBecomeActive{
    if (self.enable) {
        FTInnerLogDebug(@"[remote-config] applicationDidBecomeActive: updateRemoteConfig");
        [self updateRemoteConfig];
    }
}
- (void)shutDown{
    _updateInterval = 0;
    _enable = NO;
    _delegate = nil;
    self.isFetching = NO;
    self.lastRequestTimeInterval = 0;
    self.lastRemoteModel = nil;
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    FTInnerLogDebug(@"[remote-config] shutDown");
}
@end
