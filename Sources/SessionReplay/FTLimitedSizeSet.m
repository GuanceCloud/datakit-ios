//
//  FTLimitedSizeSet.m
//  SessionReplay
//
//  Created by hulilei on 2025/9/28.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTLimitedSizeSet.h"

@interface FTLimitedSizeSet()
@property (nonatomic, strong) NSMutableSet *storageSet;
@property (nonatomic, strong) NSMutableArray *orderArray;
@property (nonatomic, assign) NSUInteger maxCount;

@end

@implementation FTLimitedSizeSet

- (instancetype)initWithMaxCount:(NSUInteger)maxCount {
    self = [super init];
    if (self) {
        _maxCount = maxCount;
        _storageSet = [NSMutableSet set];
        _orderArray = [NSMutableArray array];
    }
    return self;
}

- (void)addObject:(id<NSCopying>)object {
    if ([self.storageSet containsObject:object]) {
        [self.storageSet removeObject:object];
        [self.orderArray removeObject:object];
    }
    
    if (self.storageSet.count >= self.maxCount) {
        id oldestObject = self.orderArray.firstObject;
        [self.storageSet removeObject:oldestObject];
        [self.orderArray removeObjectAtIndex:0];
    }
    
   
    [self.storageSet addObject:object];
    [self.orderArray addObject:object];
}

- (BOOL)containsObject:(id)object {
    return [self.storageSet containsObject:object];
}

- (void)removeObject:(id)object {
    [self.storageSet removeObject:object];
    [self.orderArray removeObject:object];
}

- (NSUInteger)count {
    return self.storageSet.count;
}

- (void)removeAllObjects {
    [self.storageSet removeAllObjects];
    [self.orderArray removeAllObjects];
}

@end

#endif
