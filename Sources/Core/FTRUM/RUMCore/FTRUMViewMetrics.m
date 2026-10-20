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

@implementation FTRUMNextViewActionParams
- (instancetype)initWithType:(NSString *)type name:(NSString *)name gapNs:(long long)gapNs nextViewName:(NSString *)nextViewName {
    if ((self = [super init])) {
        _actionType = [type copy];
        _actionName = [name copy];
        _timeToNextViewNs = gapNs;
        _nextViewName = [nextViewName copy];
    }
    return self;
}
@end

@interface FTRUMTimeBasedNextViewActionPredicate ()
@property (nonatomic, assign) long long maxTimeNs;
@end
@implementation FTRUMTimeBasedNextViewActionPredicate
- (instancetype)init { return [self initWithMaxTimeNs:3000000000LL]; }
- (instancetype)initWithMaxTimeNs:(long long)maxTimeNs {
    if ((self = [super init])) _maxTimeNs = maxTimeNs;
    return self;
}
- (BOOL)isLastAction:(FTRUMNextViewActionParams *)params {
    return [params.actionType isEqualToString:@"click"] && params.timeToNextViewNs >= 0 && params.timeToNextViewNs <= self.maxTimeNs;
}
@end

@interface FTRUMInteractionAction : NSObject
@property (nonatomic, assign) long long startNs;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *type;
@end
@implementation FTRUMInteractionAction
@end

@interface FTRUMViewMetrics ()
@property (nonatomic, assign, readwrite) long long startNs;
@property (nonatomic, strong) NSMutableArray<FTRUMInteractionAction *> *actions;
@property (nonatomic, strong) id<FTRUMNextViewActionPredicate> predicate;
@end
@implementation FTRUMViewMetrics
- (instancetype)initWithStartNs:(long long)startNs predicate:(id<FTRUMNextViewActionPredicate>)predicate {
    if ((self = [super init])) {
        _startNs = startNs;
        _actions = [NSMutableArray new];
        _predicate = predicate ?: [FTRUMTimeBasedNextViewActionPredicate new];
    }
    return self;
}
- (void)moveStartEarlierTo:(long long)startNs {
    if (startNs <= 0 || startNs >= self.startNs) return;
    self.startNs = startNs;
}
- (void)recordActionStart:(long long)startNs name:(NSString *)name type:(NSString *)type {
    FTRUMInteractionAction *action = [FTRUMInteractionAction new];
    action.startNs = startNs;
    action.name = name;
    action.type = type;
    [self.actions addObject:action];
}
- (NSNumber *)interactionToViewAt:(long long)nextStartNs name:(NSString *)nextViewName {
    // Sort by the original boundary, never callback arrival. Do not prune: another
    // destination or an earlier View origin may qualify an otherwise rejected Action.
    NSArray<FTRUMInteractionAction *> *ordered = [self.actions sortedArrayUsingComparator:^NSComparisonResult(FTRUMInteractionAction *a, FTRUMInteractionAction *b) {
        if (a.startNs == b.startNs) return NSOrderedSame;
        return a.startNs > b.startNs ? NSOrderedAscending : NSOrderedDescending;
    }];
    for (FTRUMInteractionAction *action in ordered) {
        if (self.startNs <= 0 || action.startNs < self.startNs || action.startNs > nextStartNs) continue;
        long long gapNs = nextStartNs - action.startNs;
        FTRUMNextViewActionParams *params = [[FTRUMNextViewActionParams alloc] initWithType:action.type name:action.name gapNs:gapNs nextViewName:nextViewName];
        if ([self.predicate isLastAction:params]) return @(gapNs);
    }
    return nil;
}
@end
