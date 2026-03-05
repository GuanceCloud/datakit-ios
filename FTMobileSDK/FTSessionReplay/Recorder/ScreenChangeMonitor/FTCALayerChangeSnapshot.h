//
//  FTCALayerChangeSnapshot.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/3.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTCALayerChange.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTCALayerChangeSnapshot : NSObject
@property (nonatomic, copy, readonly) NSDictionary<NSNumber *, FTCALayerChange *> *changes;

- (instancetype)initWithChanges:(NSDictionary<NSNumber *, FTCALayerChange *> *)changes;

- (FTCALayerChangeAspect)aspectsForLayer:(CALayer *)layer;

- (instancetype)removingDeallocatedLayers;

- (BOOL)isEqualToCALayerChangeSnapshot:(FTCALayerChangeSnapshot *)snapshot;

- (NSString *)description;
@end

NS_ASSUME_NONNULL_END
