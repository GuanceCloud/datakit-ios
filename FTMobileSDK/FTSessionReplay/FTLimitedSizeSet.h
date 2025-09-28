//
//  FTLimitedSizeSet.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/9/28.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTLimitedSizeSet : NSObject
- (instancetype)initWithMaxCount:(NSUInteger)maxCount;

- (void)addObject:(id<NSCopying>)object;

- (BOOL)containsObject:(id)object;

- (void)removeObject:(id)object;

- (NSUInteger)count;

- (void)removeAllObjects;
@end

NS_ASSUME_NONNULL_END
