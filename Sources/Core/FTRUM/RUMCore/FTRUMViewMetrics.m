//
//  FTRUMViewMetrics.m
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

#import "FTRUMViewMetrics.h"
#import "FTRUMAppStateHistory.h"

@interface FTRUMViewMetrics ()
@property (nonatomic, assign, readwrite) long long startNs;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *clickStarts;
@property (nonatomic, strong) NSMutableArray<NSArray<NSNumber *> *> *resourceIntervals;
@property (nonatomic, assign) long long maximumResourceEndNs;
@end
@implementation FTRUMViewMetrics
- (instancetype)initWithStartNs:(long long)startNs {
    if ((self = [super init])) {
        _startNs = startNs;
        _clickStarts = [NSMutableArray new];
        _resourceIntervals = [NSMutableArray new];
    }
    return self;
}
- (void)moveStartEarlierTo:(long long)startNs {
    if (startNs <= 0 || startNs >= self.startNs) return;
    self.startNs = startNs;
    self.maximumResourceEndNs = 0;
    for (NSArray<NSNumber *> *interval in self.resourceIntervals) {
        long long start = interval[0].longLongValue;
        if (start >= startNs && start - startNs <= 100000000LL) {
            self.maximumResourceEndNs = MAX(self.maximumResourceEndNs, interval[1].longLongValue);
        }
    }
}
- (void)recordClickStart:(long long)startNs {
    [self.clickStarts addObject:@(startNs)];
}
- (NSNumber *)interactionToViewAt:(long long)nextStartNs {
    if (self.ignoredPredecessor) return [self.ignoredPredecessor interactionToViewAt:nextStartNs];
    NSNumber *latest;
    for (NSNumber *start in self.clickStarts) {
        if (start.longLongValue < self.startNs || start.longLongValue > nextStartNs || nextStartNs - start.longLongValue > 3000000000LL) continue;
        if (!latest || start.longLongValue > latest.longLongValue) latest = start;
    }
    return latest ? @(nextStartNs - latest.longLongValue) : nil;
}
- (void)recordResourceStart:(long long)startNs end:(long long)endNs {
    if (self.startNs <= 0 || startNs <= 0 || endNs < startNs) return;
    // Later starts cannot become initial when the View origin moves earlier.
    if (startNs >= self.startNs && startNs - self.startNs > 100000000LL) return;
    [self.resourceIntervals addObject:@[@(startNs), @(endNs)]];
    if (startNs >= self.startNs) self.maximumResourceEndNs = MAX(self.maximumResourceEndNs, endNs);
}
- (BOOL)hasInitialResource { return self.maximumResourceEndNs != 0; }
- (NSNumber *)networkSettledTimeWithHistory:(FTRUMAppStateHistory *)history {
    if (self.maximumResourceEndNs == 0) return nil;
    if (!history || [history hasBackgroundOrUnavailableHistoryFrom:self.startNs to:self.maximumResourceEndNs]) return nil;
    return @(self.maximumResourceEndNs - self.startNs);
}
@end
