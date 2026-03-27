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
static NSString *const kFTRemoteConfigLastFetchedTimeKey = @"FT_REMOTE_CONFIG_LAST_FETCHED_TIME";

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
        self.lastRequestTimeInterval = [self getLastFetchedTime];
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
        if([self validateRemoteConfigRequestWithMinimumInterval:self.updateInterval completion:nil]){
            [self performRemoteConfigRequestWithCompletion:self.fetchCompletionBlock];
        }
    }else{
        FTInnerLogDebug(@"[remote-config] Skip update, appID not set or no upload address configured");
    }
}
- (void)updateRemoteConfig{
    [self updateRemoteConfigWithMinimumUpdateInterval:self.updateInterval completion:self.fetchCompletionBlock];
}

- (void)updateRemoteConfigWithMinimumUpdateInterval:(NSInteger)minimumUpdateInterval
                                         completion:(FTRemoteConfigFetchCompletionBlock)completion{
    
    FTRemoteConfigFetchCompletionBlock completionToCall = completion;
    if (!self.enable) {
        FTInnerLogWarning(@"[remote-config] Skip update: Disable remote configuration.");
        if(completionToCall) completionToCall(NO,[FTRemoteConfigError errorWithDisabled],nil,nil);
        return;
    }
    if(![[FTNetworkInfoManager sharedInstance] isNetworkConfiguredForRemote]){
        FTInnerLogWarning(@"[remote-config] Skip update: appID not set or no upload address configured.");
        if(completionToCall) completionToCall(NO,[FTRemoteConfigError errorWithCode:FTRemoteConfigErrorCodeSyncConfigMissing customDescription:nil],nil,nil);
        return;
    }
    if (![self validateRemoteConfigRequestWithMinimumInterval:minimumUpdateInterval completion:completionToCall]) {
        return;
    }
    completionToCall = completionToCall ? : self.fetchCompletionBlock;
    [self performRemoteConfigRequestWithCompletion:completionToCall];
}


#pragma mark - Core Request Logic

- (BOOL)validateRemoteConfigRequestWithMinimumInterval:(NSInteger)minimumInterval completion:(FTRemoteConfigFetchCompletionBlock)completion {
    BOOL canBeginFetch = NO;
    NSTimeInterval waitInterval = 0;
    @synchronized (self) {
        if(!self.isFetching){
            NSTimeInterval lastTimeInterval = self.lastRequestTimeInterval;
            NSTimeInterval interval = [[NSDate date] timeIntervalSince1970] - lastTimeInterval;
            
            if (lastTimeInterval > 0 && minimumInterval > 0 && interval < minimumInterval) {
                waitInterval = minimumInterval-interval;
            } else {
                self.isFetching = YES;
                canBeginFetch = YES;
            }
        }
    }
    
    if (waitInterval > 0) {
        NSString *tipMessage = [NSString stringWithFormat:@"Please wait %@ before fetching remote config again",
                      [self formatTimeIntervalShort:waitInterval]];
        FTInnerLogWarning(@"[remote-config] Skip update: %@.", tipMessage);
        if (completion) {
            NSError *error = [FTRemoteConfigError errorWithIntervalNotMet:tipMessage];
            completion(NO, error, nil, nil);
        }
        return NO;
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
- (NSString *)formatTimeIntervalShort:(NSTimeInterval)interval {
    NSInteger totalSeconds = (NSInteger)interval;
    NSInteger hours = totalSeconds / 3600;
    NSInteger minutes = (totalSeconds % 3600) / 60;
    NSInteger seconds = totalSeconds % 60;
    
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ldh %02ldm %02lds", (long)hours, (long)minutes, (long)seconds];
    } else if (minutes > 0) {
        return [NSString stringWithFormat:@"%ldm %02lds", (long)minutes, (long)seconds];
    } else {
        return [NSString stringWithFormat:@"%lds", (long)seconds];
    }
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
        NSTimeInterval fetchTimeInterval = [[NSDate date] timeIntervalSince1970];
        self.lastRequestTimeInterval = fetchTimeInterval;
        [self saveLastFetchedTime:fetchTimeInterval];
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
        FTInnerLogDebug(@"[remote-config] response data str: %@",str);
        NSString *md5 = [str ft_md5HashToLower16Bit];
        if (model && [md5 isEqualToString:model.md5Str]) {
            FTInnerLogDebug(@"[remote-config] remote config no change");
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
- (NSTimeInterval)getLastFetchedTime{
    if (!self.enable) {
        return 0;
    }
    NSNumber *time = [[NSUserDefaults standardUserDefaults] valueForKey:kFTRemoteConfigLastFetchedTimeKey];
    if (time) {
        return time.doubleValue;
    }
    return 0;
}
- (void)saveRemoteConfig:(NSDictionary<NSString *, id> *)remoteConfig{
    FTInnerLogDebug(@"[remote-config] saveRemoteConfig:%@",remoteConfig);
    [[NSUserDefaults standardUserDefaults] setObject:remoteConfig forKey:kFTRemoteConfigUserDefaultsKey];
}

- (void)saveLastFetchedTime:(NSTimeInterval)lastFetchedTime{
    [[NSUserDefaults standardUserDefaults] setObject:@(lastFetchedTime) forKey:kFTRemoteConfigLastFetchedTimeKey];
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
