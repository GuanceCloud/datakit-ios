//
//  FTVisitorIDManager.m
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTVisitorIDManager+Private.h"
#import "FTInnerLog.h"
#import <math.h>

static NSString * const FTVisitorIDDefaultsKey = @"com.guance.sdk.visitor-id.record";
static NSString * const FTVisitorIDRecordVersionKey = @"version";
static NSString * const FTVisitorIDRecordValueKey = @"id";
static NSString * const FTVisitorIDRecordCreatedAtKey = @"createdAt";
static const NSInteger FTVisitorIDRecordVersion = 1;

@interface FTVisitorIDUserDefaultsStorage : NSObject <FTVisitorIDStorage>
@end

@implementation FTVisitorIDUserDefaultsStorage
- (NSDictionary<NSString *,id> *)readRecord {
    id record = [[NSUserDefaults standardUserDefaults] objectForKey:FTVisitorIDDefaultsKey];
    return [record isKindOfClass:NSDictionary.class] ? [record copy] : nil;
}
- (BOOL)writeRecord:(NSDictionary<NSString *,id> *)record {
    [[NSUserDefaults standardUserDefaults] setObject:record forKey:FTVisitorIDDefaultsKey];
    return YES;
}
- (void)removeRecord {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:FTVisitorIDDefaultsKey];
}
@end

@interface FTVisitorIDSystemClock : NSObject <FTVisitorIDClock>
@end

@implementation FTVisitorIDSystemClock
- (NSDate *)now {
    return [NSDate date];
}
@end

@interface FTVisitorIDSnapshot ()
@property (nonatomic, copy, readwrite) NSString *value;
@property (nonatomic, strong, readwrite) NSDate *createdAt;
- (instancetype)initWithValue:(NSString *)value createdAt:(NSDate *)createdAt;
@end

@implementation FTVisitorIDSnapshot
- (instancetype)initWithValue:(NSString *)value createdAt:(NSDate *)createdAt {
    self = [super init];
    if (self) {
        _value = [value copy];
        _createdAt = createdAt;
    }
    return self;
}
@end

@interface FTVisitorIDRequestSnapshot ()
@property (nonatomic, copy, readwrite) NSString *headerName;
- (instancetype)initWithValue:(NSString *)value
                    createdAt:(NSDate *)createdAt
                   headerName:(NSString *)headerName;
@end

@implementation FTVisitorIDRequestSnapshot
- (instancetype)initWithValue:(NSString *)value
                    createdAt:(NSDate *)createdAt
                   headerName:(NSString *)headerName {
    self = [super initWithValue:value createdAt:createdAt];
    if (self) {
        _headerName = [headerName copy];
    }
    return self;
}
@end

@interface FTVisitorIDManager ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) id<FTVisitorIDStorage> storage;
@property (nonatomic, strong) id<FTVisitorIDClock> clock;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy, nullable) NSString *headerName;
@property (nonatomic, assign) NSTimeInterval ttl;
@property (nonatomic, copy, nullable) FTVisitorIDURLMatcher urlMatcher;
@property (nonatomic, assign) NSUInteger policyGeneration;
@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *resourceVisitorIDs;
@end

@implementation FTVisitorIDManager

+ (instancetype)sharedInstance {
    static FTVisitorIDManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[FTVisitorIDManager alloc]
            initWithStorage:[FTVisitorIDUserDefaultsStorage new]
                      clock:[FTVisitorIDSystemClock new]];
    });
    return manager;
}

- (instancetype)initWithStorage:(id<FTVisitorIDStorage>)storage
                           clock:(id<FTVisitorIDClock>)clock {
    self = [super init];
    if (self) {
        _storage = storage;
        _clock = clock;
        _lock = [NSLock new];
        _resourceVisitorIDs = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)bindResourceVisitorID:(NSString *)visitorID forKey:(NSString *)key {
    if (key.length == 0 || visitorID.length == 0) {
        return;
    }
    [self.lock lock];
    @try {
        if (self.enabled) {
            self.resourceVisitorIDs[key] = visitorID;
        }
    } @finally {
        [self.lock unlock];
    }
}

- (NSString *)consumeResourceVisitorIDForKey:(NSString *)key {
    if (key.length == 0) {
        return nil;
    }
    [self.lock lock];
    @try {
        NSString *visitorID = self.resourceVisitorIDs[key];
        [self.resourceVisitorIDs removeObjectForKey:key];
        return visitorID;
    } @finally {
        [self.lock unlock];
    }
}

- (void)configureWithEnabled:(BOOL)enabled
                  headerName:(NSString *)headerName
                         ttl:(NSTimeInterval)ttl
                  urlMatcher:(FTVisitorIDURLMatcher)urlMatcher {
    [self.lock lock];
    @try {
        self.policyGeneration += 1;
        self.enabled = enabled && headerName.length > 0 && ttl > 0 && isfinite(ttl) && urlMatcher != nil;
        self.headerName = self.enabled ? headerName : nil;
        self.ttl = self.enabled ? ttl : 0;
        self.urlMatcher = self.enabled ? urlMatcher : nil;
        self.value = nil;
        self.createdAt = nil;
        if (self.enabled) {
            [self loadOrCreateAtDate:[self.clock now]];
        }
    } @finally {
        [self.lock unlock];
    }
}

- (FTVisitorIDSnapshot *)snapshot {
    [self.lock lock];
    @try {
        if (!self.enabled) {
            return nil;
        }
        return [self snapshotAtDate:[self.clock now]];
    } @finally {
        [self.lock unlock];
    }
}

- (FTVisitorIDRequestSnapshot *)requestSnapshotForURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    __block FTVisitorIDURLMatcher matcher = nil;
    __block NSString *headerName = nil;
    __block NSUInteger generation = 0;
    [self.lock lock];
    @try {
        if (!self.enabled) {
            return nil;
        }
        matcher = [self.urlMatcher copy];
        headerName = [self.headerName copy];
        generation = self.policyGeneration;
    } @finally {
        [self.lock unlock];
    }
    if (![self safelyMatchesURL:url matcher:matcher]) {
        return nil;
    }
    [self.lock lock];
    @try {
        if (!self.enabled || generation != self.policyGeneration ||
            ![headerName isEqualToString:self.headerName]) {
            return nil;
        }
        FTVisitorIDSnapshot *snapshot = [self snapshotAtDate:[self.clock now]];
        if (!snapshot) {
            return nil;
        }
        return [[FTVisitorIDRequestSnapshot alloc] initWithValue:snapshot.value
                                                       createdAt:snapshot.createdAt
                                                      headerName:headerName];
    } @finally {
        [self.lock unlock];
    }
}

- (void)reset {
    [self.lock lock];
    @try {
        @try {
            [self.storage removeRecord];
        } @catch (NSException *exception) {
            FTInnerLogWarning(@"Visitor ID storage reset failed: %@", exception.reason);
        }
        self.value = nil;
        self.createdAt = nil;
        if (self.enabled) {
            [self rotateAtDate:[self.clock now]];
        }
    } @finally {
        [self.lock unlock];
    }
}

- (void)shutDown {
    [self.lock lock];
    @try {
        self.policyGeneration += 1;
        self.enabled = NO;
        self.headerName = nil;
        self.ttl = 0;
        self.urlMatcher = nil;
        self.value = nil;
        self.createdAt = nil;
        [self.resourceVisitorIDs removeAllObjects];
    } @finally {
        [self.lock unlock];
    }
}

#pragma mark - Locked helpers

- (nullable FTVisitorIDSnapshot *)snapshotAtDate:(NSDate *)date {
    if (![self isValueActive:self.value createdAt:self.createdAt now:date]) {
        if (self.value == nil) {
            [self loadOrCreateAtDate:date];
        } else {
            [self rotateAtDate:date];
        }
    }
    if (!self.value || !self.createdAt) {
        return nil;
    }
    return [[FTVisitorIDSnapshot alloc] initWithValue:self.value createdAt:self.createdAt];
}

- (void)loadOrCreateAtDate:(NSDate *)date {
    NSDictionary *record = nil;
    @try {
        record = [self.storage readRecord];
    } @catch (__unused NSException *exception) {
        record = nil;
    }
    if ([record isKindOfClass:NSDictionary.class] &&
        [record[FTVisitorIDRecordVersionKey] isKindOfClass:NSNumber.class] &&
        [record[FTVisitorIDRecordVersionKey] integerValue] == FTVisitorIDRecordVersion &&
        [record[FTVisitorIDRecordValueKey] isKindOfClass:NSString.class] &&
        [record[FTVisitorIDRecordCreatedAtKey] isKindOfClass:NSNumber.class]) {
        NSString *value = record[FTVisitorIDRecordValueKey];
        NSDate *createdAt = [NSDate dateWithTimeIntervalSince1970:[record[FTVisitorIDRecordCreatedAtKey] doubleValue]];
        if ([self isValidPersistedIdentifier:value] &&
            [self isValueActive:value createdAt:createdAt now:date]) {
            self.value = value;
            self.createdAt = createdAt;
            return;
        }
    }
    [self rotateAtDate:date];
}

- (void)rotateAtDate:(NSDate *)date {
    NSString *random = [[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""].lowercaseString;
    NSString *persistentValue = [@"p" stringByAppendingString:random];
    NSDictionary *record = @{
        FTVisitorIDRecordVersionKey: @(FTVisitorIDRecordVersion),
        FTVisitorIDRecordValueKey: persistentValue,
        FTVisitorIDRecordCreatedAtKey: @([date timeIntervalSince1970]),
    };
    BOOL persisted = NO;
    @try {
        persisted = [self.storage writeRecord:record];
        if (persisted) {
            NSDictionary *readBack = [self.storage readRecord];
            persisted = [readBack isEqualToDictionary:record];
        }
    } @catch (__unused NSException *exception) {
        persisted = NO;
    }
    self.value = [(persisted ? @"p" : @"s") stringByAppendingString:random];
    self.createdAt = date;
}

- (BOOL)isValidPersistedIdentifier:(NSString *)value {
    if (value.length != 33 || [value characterAtIndex:0] != 'p') {
        return NO;
    }
    for (NSUInteger index = 1; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        if (!((character >= '0' && character <= '9') ||
              (character >= 'a' && character <= 'f'))) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)isValueActive:(NSString *)value
             createdAt:(NSDate *)createdAt
                   now:(NSDate *)now {
    if (!self.enabled || value.length == 0 || !createdAt || !now) {
        return NO;
    }
    NSTimeInterval created = createdAt.timeIntervalSince1970;
    NSTimeInterval current = now.timeIntervalSince1970;
    return isfinite(created) && isfinite(current) && created >= 0 && current >= created &&
        current - created < self.ttl;
}

- (BOOL)safelyMatchesURL:(NSURL *)url matcher:(FTVisitorIDURLMatcher)matcher {
    if (!matcher) {
        return NO;
    }
    @try {
        return matcher(url);
    } @catch (NSException *exception) {
        FTInnerLogWarning(@"Visitor ID URL matcher failed: %@", exception.reason);
        return NO;
    }
}

@end
