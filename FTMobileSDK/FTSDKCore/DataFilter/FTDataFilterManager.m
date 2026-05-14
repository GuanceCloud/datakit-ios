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
@property (nonatomic, assign) BOOL isFetching;
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

- (void)enable:(BOOL)enable
localFilters:(NSDictionary<NSString *, NSArray<NSString *> *> *)localFilters
updateInterval:(int)updateInterval {
    @synchronized (self) {
        self.enable = enable;
        self.updateInterval = updateInterval > 0 ? updateInterval : FTDataFilterDefaultUpdateInterval;
        self.localFilter = [[FTDataFilter alloc] initWithFilters:[self sanitizedFilters:localFilters]];
        self.remoteFilter = nil;
        self.remoteMD5 = nil;
        self.shouldDisableServerFilter = NO;
        self.lastRequestTimeInterval = 0;
        self.isFetching = NO;
    }
    if (enable) {
        [self updateRemoteFilterIfNeededWithForce:YES];
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
    @synchronized (self) {
        if (!self.enable || self.isFetching || ![FTNetworkInfoManager sharedInstance].isNetworkConfigured) {
            return;
        }
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (!force && self.lastRequestTimeInterval > 0 && now - self.lastRequestTimeInterval < self.updateInterval) {
            return;
        }
        self.isFetching = YES;
        self.lastRequestTimeInterval = now;
    }
    FTInnerLogDebug(@"[data-filter] Start pulling remote filters.");
    FTDataFilterPullRequest *request = [[FTDataFilterPullRequest alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.httpClient sendRequest:request completion:^(NSHTTPURLResponse * _Nullable httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf handleResponse:httpResponse data:data error:error];
    }];
}

- (void)handleResponse:(NSHTTPURLResponse *)httpResponse data:(NSData *)data error:(NSError *)error {
    @try {
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
        NSString *md5 = [body ft_md5HashToLower16Bit];
        @synchronized (self) {
            if (self.remoteMD5 && [self.remoteMD5 isEqualToString:md5]) {
                self.shouldDisableServerFilter = YES;
                return;
            }
        }
        NSDictionary *response = [FTJSONUtil dictionaryWithJsonString:body];
        NSDictionary *filters = [self sanitizedFilters:response[@"filters"]];
        FTDataFilter *remoteFilter = [[FTDataFilter alloc] initWithFilters:filters];
        int interval = [self intervalFromPullInterval:response[@"pull_interval"]];
        @synchronized (self) {
            self.remoteFilter = remoteFilter;
            self.remoteMD5 = md5;
            self.shouldDisableServerFilter = YES;
            if (interval > 0) {
                self.updateInterval = interval;
            }
        }
        FTInnerLogDebug(@"[data-filter] Complete pulling remote filters.");
    } @catch (NSException *exception) {
        FTInnerLogError(@"[data-filter] Parse remote filters exception: %@", exception);
    } @finally {
        @synchronized (self) {
            self.isFetching = NO;
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
    if (!self.enable) {
        return NO;
    }
    [self updateRemoteFilterIfNeededWithForce:NO];
    FTDataFilter *localFilter = nil;
    FTDataFilter *remoteFilter = nil;
    @synchronized (self) {
        localFilter = self.localFilter;
        remoteFilter = self.remoteFilter;
    }
    if ([localFilter isMatchedWithCategory:category source:source tags:tags fields:fields]) {
        FTInnerLogDebug(@"drop data by local filter, category:%@, measurement:%@, uuid:%@", category, source, uuid);
        return YES;
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
        self.shouldDisableServerFilter = NO;
        self.isFetching = NO;
        self.lastRequestTimeInterval = 0;
    }
}

@end
