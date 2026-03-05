//
//  FTCALayerChange.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/3.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTCALayerChange.h"

@implementation FTCALayerChange

- (instancetype)initWithLayer:(CALayer *)layer aspects:(FTCALayerChangeAspect)aspects {
    if (self = [super init]) {
        _layer = layer;
        _aspects = aspects;
    }
    return self;
}

@end
