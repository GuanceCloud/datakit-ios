//
//  FTRUMNetworkSettledMetric.m
//  FTMobileAgent
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

#import "FTRUMNetworkSettledMetric.h"
#import "FTRUMAppStateHistory.h"

@implementation FTRUMNetworkSettledResourceParams
- (instancetype)initWithURL:(NSString *)URL viewName:(NSString *)viewName offsetNs:(long long)offsetNs {
    if ((self = [super init])) {
        _resourceURL = [URL copy];
        _viewName = [viewName copy];
        _timeSinceViewStartNs = offsetNs;
    }
    return self;
}
@end

@interface FTRUMTimeBasedNetworkSettledPredicate ()
@property (nonatomic, assign) long long thresholdNs;
@end
@implementation FTRUMTimeBasedNetworkSettledPredicate
- (instancetype)init { return [self initWithThresholdNs:100000000LL]; }
- (instancetype)initWithThresholdNs:(long long)thresholdNs {
    if ((self = [super init])) _thresholdNs = thresholdNs;
    return self;
}
- (BOOL)isInitialResource:(FTRUMNetworkSettledResourceParams *)params {
    return params.timeSinceViewStartNs >= 0 && params.timeSinceViewStartNs <= self.thresholdNs;
}
@end

@interface FTRUMNetworkSettledResource : NSObject
@property (nonatomic, assign) long long startNs;
@property (nonatomic, copy, nullable) NSString *URL;
@property (nonatomic, strong, nullable) NSNumber *endNs;
@property (nonatomic, assign) BOOL terminal;
@end
@implementation FTRUMNetworkSettledResource
@end

@interface FTRUMNetworkSettledMetric ()
@property (nonatomic, assign) long long startNs;
@property (nonatomic, copy) NSString *viewName;
@property (nonatomic, strong) id<FTRUMNetworkSettledResourcePredicate> predicate;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FTRUMNetworkSettledResource *> *resources;
@property (nonatomic, copy) NSSet<NSString *> *completedBatchKeys;
@property (nonatomic, strong, nullable) NSNumber *completedBatchEndNs;
@end
@implementation FTRUMNetworkSettledMetric
- (instancetype)initWithStartNs:(long long)startNs viewName:(NSString *)viewName predicate:(id<FTRUMNetworkSettledResourcePredicate>)predicate {
    if ((self = [super init])) {
        _startNs = startNs;
        _viewName = [viewName copy];
        _predicate = predicate ?: [FTRUMTimeBasedNetworkSettledPredicate new];
        _resources = [NSMutableDictionary new];
        _completedBatchKeys = [NSSet set];
    }
    return self;
}
- (BOOL)isInitial:(FTRUMNetworkSettledResource *)resource {
    if (self.startNs <= 0 || resource.startNs < self.startNs) return NO;
    FTRUMNetworkSettledResourceParams *params = [[FTRUMNetworkSettledResourceParams alloc]
        initWithURL:resource.URL viewName:self.viewName offsetNs:resource.startNs - self.startNs];
    return [self.predicate isInitialResource:params];
}
- (void)refreshCompletedBatch {
    BOOL pendingInitial = NO;
    for (FTRUMNetworkSettledResource *resource in self.resources.allValues) {
        if (!resource.terminal && [self isInitial:resource]) { pendingInitial = YES; break; }
    }
    if (!pendingInitial) {
        NSMutableSet *keys = [NSMutableSet new];
        [self.resources enumerateKeysAndObjectsUsingBlock:^(NSString *key, FTRUMNetworkSettledResource *resource, BOOL *stop) {
            if (resource.endNs) [keys addObject:key];
        }];
        self.completedBatchKeys = keys;
    }
    NSNumber *maximumEnd = nil;
    for (NSString *key in self.completedBatchKeys) {
        FTRUMNetworkSettledResource *resource = self.resources[key];
        if ([self isInitial:resource] && (!maximumEnd || resource.endNs.longLongValue > maximumEnd.longLongValue)) maximumEnd = resource.endNs;
    }
    self.completedBatchEndNs = maximumEnd;
}
- (void)startResourceWithKey:(NSString *)key startNs:(long long)startNs URL:(NSString *)URL {
    if (self.resources[key]) return;
    FTRUMNetworkSettledResource *resource = [FTRUMNetworkSettledResource new];
    resource.startNs = startNs;
    resource.URL = URL;
    self.resources[key] = resource;
    [self refreshCompletedBatch];
}
- (void)updateResourceWithKey:(NSString *)key startNs:(long long)startNs URL:(NSString *)URL {
    FTRUMNetworkSettledResource *resource = self.resources[key];
    if (!resource || resource.terminal) return;
    resource.startNs = startNs;
    if (URL) resource.URL = URL;
    [self refreshCompletedBatch];
}
- (void)completeResourceWithKey:(NSString *)key endNs:(long long)endNs {
    FTRUMNetworkSettledResource *resource = self.resources[key];
    if (!resource || resource.terminal) return;
    resource.terminal = YES;
    if (resource.startNs > 0 && endNs >= resource.startNs) resource.endNs = @(endNs);
    [self refreshCompletedBatch];
}
- (void)dropResourceWithKey:(NSString *)key {
    FTRUMNetworkSettledResource *resource = self.resources[key];
    if (!resource || resource.terminal) return;
    resource.terminal = YES;
    [self refreshCompletedBatch];
}
- (void)moveStartEarlierTo:(long long)startNs {
    if (startNs <= 0 || startNs >= self.startNs) return;
    self.startNs = startNs;
    [self refreshCompletedBatch];
}
- (NSNumber *)valueWithHistory:(FTRUMAppStateHistory *)history {
    if (!self.completedBatchEndNs || !history || [history hasBackgroundOrUnavailableHistoryFrom:self.startNs to:self.completedBatchEndNs.longLongValue]) return nil;
    return @(self.completedBatchEndNs.longLongValue - self.startNs);
}
@end
