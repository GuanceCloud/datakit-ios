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

static NSString *const kFTRemoteConfigUserDefaultsKey = @"FT_REMOTE_CONFIG";

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

#pragma mark - Initialization

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

#pragma mark - Configuration

- (void)enable:(BOOL)enable updateInterval:(int)updateInterval remoteConfigFetchCompletionBlock:(FTRemoteConfigFetchCompletionBlock)fetchCompletionBlock{
    _enable = enable;
    _updateInterval = updateInterval;
    self.fetchCompletionBlock = fetchCompletionBlock;
    if (enable) {
        self.lastRemoteModel = [[FTRemoteConfigModel alloc]initWithDict:[self getLastFetchedRemoteConfig]];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
}

#pragma mark - Public API
/// SDK Inner API
- (void)innerUpdateRemoteConfig{
    if (!self.enable){
        return;
    }
    if([[FTNetworkInfoManager sharedInstance] isNetworkConfiguredForRemote]) {
        FTInnerLogDebug(@"[remote-config] innerUpdateRemoteConfig start");
        [self requestRemoteConfig:self.updateInterval completion:self.fetchCompletionBlock];
    }else{
        FTInnerLogDebug(@"[remote-config] Skip update, appID not set or no upload address configured");
    }
}
- (void)updateRemoteConfig{
    [self updateRemoteConfigWithMinimumUpdateInterval:self.updateInterval completion:self.fetchCompletionBlock];
}

- (void)updateRemoteConfigWithMinimumUpdateInterval:(NSInteger)minimumUpdateInterval
                                         completion:(FTRemoteConfigFetchCompletionBlock)completion{
    
    FTRemoteConfigFetchCompletionBlock completionToCall = completion ?: self.fetchCompletionBlock;
    if (!self.enable) {
        FTInnerLogDebug(@"[remote-config] Skip update: Disable remote configuration.");
        if(completionToCall) completionToCall(NO,[FTRemoteConfigError errorWithDisabled],nil,nil);
        return;
    }
    if(![[FTNetworkInfoManager sharedInstance] isNetworkConfiguredForRemote]){
        FTInnerLogDebug(@"[remote-config] Skip update: appID not set or no upload address configured.");
        if(completionToCall) completionToCall(NO,[FTRemoteConfigError errorWithCode:FTRemoteConfigErrorCodeSyncConfigMissing customDescription:nil],nil,nil);
        return;
    }
    [self requestRemoteConfig:minimumUpdateInterval completion:completionToCall];
}


#pragma mark - Core Request Logic

- (void)requestRemoteConfig:(NSInteger)minimumUpdateInterval completion:(FTRemoteConfigFetchCompletionBlock)completion{
    if (![self validateRemoteConfigRequestWithMinimumInterval:minimumUpdateInterval completion:completion]) {
        return;
    }
    [self performRemoteConfigRequestWithCompletion:completion];
}

- (BOOL)validateRemoteConfigRequestWithMinimumInterval:(NSInteger)minimumInterval completion:(FTRemoteConfigFetchCompletionBlock)completion {
    
    if (self.lastRequestTimeInterval > 0 && minimumInterval > 0 && [[NSDate date] timeIntervalSince1970] - self.lastRequestTimeInterval < minimumInterval) {
        FTInnerLogDebug(@"[remote-config] Skip update: The time interval between last request is shorter than mini Update Interval.");
        if (completion) {
            NSError *error = [FTRemoteConfigError errorWithIntervalNotMet:minimumInterval];
            completion(NO, error, nil, nil);
        }
        return NO;
    }
    
    BOOL canBeginFetch = NO;
    @synchronized(self) {
        if (!self.isFetching) {
            self.isFetching = YES;
            canBeginFetch = YES;
        }
    }
    
    if (!canBeginFetch) {
        FTInnerLogDebug(@"[remote-config] Skip update: Request is being processed.");
        if (completion) {
            NSError *error = [FTRemoteConfigError errorWithRequesting];
            completion(NO, error, nil, nil);
        }
        return NO;
    }
    
    return YES;
}

- (void)performRemoteConfigRequestWithCompletion:(FTRemoteConfigFetchCompletionBlock)completion {
    FTInnerLogDebug(@"[remote-config] Start loading remote configuration.");
    FTRemoteConfigurationRequest *request = [[FTRemoteConfigurationRequest alloc] init];
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
        
        [strongSelf handleRemoteConfigResponse:httpResponse data:data error:error completion:completion];
    }];
}

- (void)handleRemoteConfigResponse:(NSHTTPURLResponse *)httpResponse 
                              data:(NSData *)data 
                             error:(NSError *)error 
                        completion:(FTRemoteConfigFetchCompletionBlock)completion {
    BOOL isSuccess = NO;
    NSError *requestError = nil;
    FTRemoteConfigModel *model = nil;
    NSDictionary *content = nil;
    
    if (error) {
        requestError = [FTRemoteConfigError errorWithNetworkFailed:error];
        FTInnerLogError(@"[remote-config] Network request failed: %@ (code: %ld)", 
                       error.localizedDescription, (long)error.code);
    } else if (httpResponse.statusCode != 200) {
        NSString *desc = [NSString stringWithFormat:@"Invalid HTTP status code: %ld (expected 200)", 
                         (long)httpResponse.statusCode];
        requestError = [FTRemoteConfigError errorWithCode:FTRemoteConfigErrorCodeNetworkFailed
                                         customDescription:desc];
        FTInnerLogError(@"[remote-config] Invalid status code: %ld", (long)httpResponse.statusCode);
    } else if (!data || data.length == 0) {
        requestError = [FTRemoteConfigError errorWithParseFailed:@"Empty response data from remote config server"];
        FTInnerLogError(@"[remote-config] Empty response data");
    } else {
        isSuccess = YES;
        model = [self handleRemoteConfigData:data];
        self.lastRequestTimeInterval = [[NSDate date] timeIntervalSince1970];
        content = model.context;
    }
    
    if (completion) {
        FTRemoteConfigModel *finalModel = completion(isSuccess, requestError,
            model ? [model copy] : nil,
            content ? [content copy] : nil);
        if (finalModel) {
            model = [finalModel copy];
        }
    }
    
    if (isSuccess) {
        self.lastRemoteModel = model;
        if (model) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(remoteConfigurationDidChange)]) {
                [self.delegate remoteConfigurationDidChange];
            }
            [self saveRemoteConfig:[model toDictionary]];
            FTInnerLogDebug(@"[remote-config] Remote config parsed successfully");
        } else {
            [self saveRemoteConfig:nil];
            FTInnerLogWarning(@"[remote-config] Remote config parsed to nil");
        }
    }
    
    self.isFetching = NO;
    FTInnerLogDebug(@"[remote-config] Complete the loading of the remote configuration.");
}
   
#pragma mark - Data Processing & Local Storage

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

- (NSDictionary *)getLastFetchedRemoteConfig{
    if (!self.enable) {
        return nil;
    }
    NSDictionary *local = [[NSUserDefaults standardUserDefaults] objectForKey:kFTRemoteConfigUserDefaultsKey];
    return local;
}

- (void)saveRemoteConfig:(NSDictionary<NSString *, id> *)remoteConfig{
    [[NSUserDefaults standardUserDefaults] setObject:remoteConfig forKey:kFTRemoteConfigUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - App Lifecycle Delegate

-(void)applicationDidBecomeActive{
    if (self.enable) {
        FTInnerLogDebug(@"[remote-config] applicationDidBecomeActive: updateRemoteConfig");
        [self innerUpdateRemoteConfig];
    }
}

#pragma mark - Cleanup

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
