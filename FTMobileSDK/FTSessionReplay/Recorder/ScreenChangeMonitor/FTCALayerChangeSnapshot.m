//
//  FTCALayerChangeSnapshot.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/3.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTCALayerChangeSnapshot.h"

@implementation FTCALayerChangeSnapshot
- (instancetype)initWithChanges:(NSDictionary<NSNumber *, FTCALayerChange *> *)changes {
    if (self = [super init]) {
        _changes = [changes copy];
    }
    return self;
}

- (FTCALayerChangeAspect)aspectsForLayer:(CALayer *)layer {
    NSNumber *key = @((uintptr_t)layer);
    FTCALayerChange *change = self.changes[key];
    return change ? change.aspects : 0;
}

- (instancetype)removingDeallocatedLayers {
    NSMutableDictionary *filteredChanges = [NSMutableDictionary dictionary];
    [self.changes enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, FTCALayerChange * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.layer) {
            filteredChanges[key] = obj;
        }
    }];
    return [self initWithChanges:filteredChanges];
}

- (BOOL)isEqualToCALayerChangeSnapshot:(FTCALayerChangeSnapshot *)snapshot {
    if (self == snapshot) return YES;
    if (!snapshot) return NO;
    return [self.changes isEqualToDictionary:snapshot.changes];
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[FTCALayerChangeSnapshot class]]) {
        return [self isEqualToCALayerChangeSnapshot:(FTCALayerChangeSnapshot *)object];
    }
    return NO;
}

- (NSUInteger)hash {
    return self.changes.hash;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nullable [_Nonnull])buffer count:(NSUInteger)len {
    return [self.changes.allValues countByEnumeratingWithState:state objects:buffer count:len];
}

- (NSString *)description {
    NSUInteger layerCount = self.changes.count;
    __block NSUInteger displayCount = 0;
    __block NSUInteger drawCount = 0;
    __block NSUInteger layoutCount = 0;
    
    [self.changes enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, FTCALayerChange * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.aspects & FTCALayerChangeAspectDisplay) {
            displayCount++;
        }
        if (obj.aspects & FTCALayerChangeAspectDraw) {
            drawCount++;
        }
        if (obj.aspects & FTCALayerChangeAspectLayout) {
            layoutCount++;
        }
    }];
    
    return [NSString stringWithFormat:@"(layers: %lu,displays: %lu,draws: %lu,layouts: %lu)",
            (unsigned long)layerCount,
            (unsigned long)displayCount,
            (unsigned long)drawCount,
            (unsigned long)layoutCount];
}
@end
