//
//  FTDataFilterManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
//

#import "FTDataFilterManager.h"
#import "FTDataFilter.h"
#import "FTDataFilterPullRequest.h"
#import "FTHTTPClient.h"
#import "FTInnerLog.h"
#import "FTJSONUtil.h"
#import "FTNetworkInfoManager.h"
#import "NSString+FTAdd.h"

static const int FTDataFilterDefaultUpdateInterval = 30 * 60;

@interface FTDataFilterManager()
@property (nonatomic, assign) BOOL enable;
@property (nonatomic, assign) int updateInterval;
@property (nonatomic, strong) FTDataFilter *localFilter;
@property (nonatomic, strong) FTDataFilter *remoteFilter;
@property (nonatomic, copy) NSString *remoteMD5;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, copy) NSString *endpointKey;
@property (nonatomic, assign) NSUInteger activeRequestCount;
@property (nonatomic, assign) NSTimeInterval lastRequestTimeInterval;
@property (nonatomic, assign, readwrite) BOOL shouldDisableServerFilter;
@property (nonatomic, strong) FTHTTPClient *httpClient;
@end

@implementation FTDataFilterManager

static FTDataFilterManager *sharedManager = nil;
static dispatch_once_t onceToken;

+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedManager = [[FTDataFilterManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _updateInterval = FTDataFilterDefaultUpdateInterval;
        _httpClient = [[FTHTTPClient alloc] init];
    }
    return self;
}

- (BOOL)shouldDisableServerFilter {
    @synchronized (self) {
        return _shouldDisableServerFilter;
    }
}

- (void)enable:(BOOL)enable
localFilters:(NSDictionary<NSString *, NSArray<NSString *> *> *)localFilters
updateInterval:(int)updateInterval {
    FTDataFilter *localFilter = enable ? [self dataFilterWithFilters:localFilters logPrefix:@"local"] : nil;
    NSString *endpointKey = [self currentEndpointKey];
    @synchronized (self) {
        self.generation++;
        self.enable = enable;
        self.updateInterval = updateInterval > 0 ? updateInterval : FTDataFilterDefaultUpdateInterval;
        self.localFilter = localFilter;
        self.remoteFilter = nil;
        self.remoteMD5 = nil;
        self.endpointKey = endpointKey;
        _shouldDisableServerFilter = NO;
        self.lastRequestTimeInterval = 0;
        self.activeRequestCount = 0;
    }
    if (enable) {
        [self updateRemoteFilterIfNeededWithForce:YES];
    }
}

- (FTDataFilter *)dataFilterWithFilters:(NSDictionary *)filters logPrefix:(NSString *)logPrefix {
    @try {
        return [[FTDataFilter alloc] initWithFilters:[self sanitizedFilters:filters]];
    } @catch (NSException *exception) {
        FTInnerLogError(@"[data-filter] Compile %@ filters exception: %@", logPrefix, exception);
        return [[FTDataFilter alloc] initWithFilters:@{}];
    }
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)sanitizedFilters:(NSDictionary *)filters {
    if (![filters isKindOfClass:NSDictionary.class]) {
        return @{};
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *category in @[@"logging", @"rum"]) {
        id rules = filters[category];
        if ([rules isKindOfClass:NSArray.class]) {
            NSMutableArray *validRules = [NSMutableArray array];
            for (id rule in rules) {
                if ([rule isKindOfClass:NSString.class] && [rule length] > 0) {
                    [validRules addObject:rule];
                }
            }
            if (validRules.count > 0) {
                result[category] = [validRules copy];
            }
        }
    }
    return [result copy];
}

- (void)updateRemoteFilterIfNeededWithForce:(BOOL)force {
    NSUInteger requestGeneration = 0;
    NSString *requestEndpointKey = nil;
    @synchronized (self) {
        if (!self.enable || ![FTNetworkInfoManager sharedInstance].isNetworkConfigured) {
            return;
        }
        NSString *endpointKey = [self currentEndpointKey];
        if (endpointKey.length == 0) {
            return;
        }
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (force) {
            BOOL endpointChanged = self.endpointKey.length > 0 && ![self.endpointKey isEqualToString:endpointKey];
            self.generation++;
            self.endpointKey = endpointKey;
            self.activeRequestCount = 0;
            if (endpointChanged) {
                self.remoteFilter = nil;
                self.remoteMD5 = nil;
                _shouldDisableServerFilter = NO;
            }
        } else if (self.activeRequestCount > 0) {
            return;
        }
        if (!force && self.lastRequestTimeInterval > 0 && now - self.lastRequestTimeInterval < self.updateInterval) {
            return;
        }
        self.activeRequestCount++;
        self.lastRequestTimeInterval = now;
        requestGeneration = self.generation;
        requestEndpointKey = [self.endpointKey copy];
    }
    FTInnerLogDebug(@"[data-filter] Start pulling remote filters.");
    FTDataFilterPullRequest *request = [[FTDataFilterPullRequest alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.httpClient sendRequest:request completion:^(NSHTTPURLResponse * _Nullable httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf handleResponse:httpResponse data:data error:error generation:requestGeneration endpointKey:requestEndpointKey];
    }];
}

- (void)handleResponse:(NSHTTPURLResponse *)httpResponse
                  data:(NSData *)data
                 error:(NSError *)error
            generation:(NSUInteger)generation
           endpointKey:(NSString *)endpointKey {
    @try {
        if (![self isCurrentRequestWithGeneration:generation endpointKey:endpointKey]) {
            return;
        }
        if (error) {
            FTInnerLogError(@"[data-filter] Pull remote filters failed: %@", error.localizedDescription);
            return;
        }
        if (httpResponse.statusCode != 200) {
            FTInnerLogError(@"[data-filter] Pull remote filters failed, status code: %ld", (long)httpResponse.statusCode);
            return;
        }
        if (data.length == 0) {
            FTInnerLogError(@"[data-filter] Pull remote filters failed: empty response.");
            return;
        }
        NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (body.length == 0) {
            FTInnerLogError(@"[data-filter] Pull remote filters failed: invalid response encoding.");
            return;
        }
        NSString *md5 = [body ft_md5HashToLower16Bit];
        @synchronized (self) {
            if (![self isCurrentRequestLockedWithGeneration:generation endpointKey:endpointKey]) {
                return;
            }
            if (self.remoteMD5 && [self.remoteMD5 isEqualToString:md5]) {
                _shouldDisableServerFilter = YES;
                return;
            }
        }
        NSDictionary *response = [FTJSONUtil dictionaryWithJsonString:body];
        if (![response isKindOfClass:NSDictionary.class]) {
            FTInnerLogError(@"[data-filter] Pull remote filters failed: invalid response json.");
            return;
        }
        id filtersValue = response[@"filters"];
        if (![filtersValue isKindOfClass:NSDictionary.class]) {
            FTInnerLogError(@"[data-filter] Pull remote filters failed: invalid filters schema.");
            return;
        }
        FTDataFilter *remoteFilter = [self dataFilterWithFilters:filtersValue logPrefix:@"remote"];
        int interval = [self intervalFromPullInterval:response[@"pull_interval"]];
        @synchronized (self) {
            if (![self isCurrentRequestLockedWithGeneration:generation endpointKey:endpointKey]) {
                return;
            }
            self.remoteFilter = remoteFilter;
            self.remoteMD5 = md5;
            _shouldDisableServerFilter = YES;
            if (interval > 0) {
                self.updateInterval = interval;
            }
        }
        FTInnerLogDebug(@"[data-filter] Complete pulling remote filters.");
    } @catch (NSException *exception) {
        FTInnerLogError(@"[data-filter] Parse remote filters exception: %@", exception);
    } @finally {
        [self finishRequestWithGeneration:generation endpointKey:endpointKey];
    }
}

- (NSString *)currentEndpointKey {
    FTNetworkInfoManager *info = [FTNetworkInfoManager sharedInstance];
    switch (info.configState) {
        case FTNetworkConfigStateDatakitMode:
            return info.datakitUrl.length > 0 ? [NSString stringWithFormat:@"datakit:%@", info.datakitUrl] : nil;
        case FTNetworkConfigStateDatawayMode:
            return (info.datawayUrl.length > 0 && info.clientToken.length > 0) ? [NSString stringWithFormat:@"dataway:%@:%@", info.datawayUrl, info.clientToken] : nil;
        default:
            return nil;
    }
}

- (BOOL)isCurrentRequestWithGeneration:(NSUInteger)generation endpointKey:(NSString *)endpointKey {
    @synchronized (self) {
        return [self isCurrentRequestLockedWithGeneration:generation endpointKey:endpointKey];
    }
}

- (BOOL)isCurrentRequestLockedWithGeneration:(NSUInteger)generation endpointKey:(NSString *)endpointKey {
    return self.enable && generation == self.generation && endpointKey.length > 0 && [self.endpointKey isEqualToString:endpointKey];
}

- (void)finishRequestWithGeneration:(NSUInteger)generation endpointKey:(NSString *)endpointKey {
    @synchronized (self) {
        if ([self isCurrentRequestLockedWithGeneration:generation endpointKey:endpointKey] && self.activeRequestCount > 0) {
            self.activeRequestCount--;
        }
    }
}

- (int)intervalFromPullInterval:(id)value {
    if (![value isKindOfClass:NSString.class] || [value length] == 0) {
        return 0;
    }
    NSString *interval = [value lowercaseString];
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSString *numberString = [[interval componentsSeparatedByCharactersInSet:digits.invertedSet] componentsJoinedByString:@""];
    int number = numberString.intValue;
    if (number <= 0) {
        return 0;
    }
    if ([interval hasSuffix:@"ms"]) return MAX(1, number / 1000);
    if ([interval hasSuffix:@"s"]) return number;
    if ([interval hasSuffix:@"h"]) return number * 60 * 60;
    if ([interval hasSuffix:@"m"]) return number * 60;
    return number;
}

- (BOOL)isFilteredWithCategory:(NSString *)category
                        source:(NSString *)source
                          uuid:(NSString *)uuid
                          tags:(NSDictionary *)tags
                        fields:(NSDictionary *)fields {
    return [self isFilteredWithCategory:category
                                 source:source
                                   uuid:uuid
                                   tags:tags
                                 fields:fields
                    remoteFilterChecked:nil];
}

- (BOOL)isFilteredWithCategory:(NSString *)category
                        source:(NSString *)source
                          uuid:(NSString *)uuid
                          tags:(NSDictionary *)tags
                        fields:(NSDictionary *)fields
           remoteFilterChecked:(BOOL *)remoteFilterChecked {
    BOOL enable = NO;
    FTDataFilter *localFilter = nil;
    FTDataFilter *remoteFilter = nil;
    if (remoteFilterChecked) {
        *remoteFilterChecked = NO;
    }
    @synchronized (self) {
        enable = self.enable;
        localFilter = self.localFilter;
        remoteFilter = self.remoteFilter;
    }
    if (!enable) {
        return NO;
    }
    if ([localFilter isMatchedWithCategory:category source:source tags:tags fields:fields]) {
        FTInnerLogDebug(@"drop data by local filter, category:%@, measurement:%@, uuid:%@", category, source, uuid);
        return YES;
    }
    if (remoteFilterChecked && remoteFilter) {
        *remoteFilterChecked = YES;
    }
    if ([remoteFilter isMatchedWithCategory:category source:source tags:tags fields:fields]) {
        FTInnerLogDebug(@"drop data by remote filter, category:%@, measurement:%@, uuid:%@", category, source, uuid);
        return YES;
    }
    return NO;
}

- (void)shutDown {
    @synchronized (self) {
        self.enable = NO;
        self.localFilter = nil;
        self.remoteFilter = nil;
        self.remoteMD5 = nil;
        self.generation++;
        self.endpointKey = nil;
        _shouldDisableServerFilter = NO;
        self.activeRequestCount = 0;
        self.lastRequestTimeInterval = 0;
    }
}

@end
