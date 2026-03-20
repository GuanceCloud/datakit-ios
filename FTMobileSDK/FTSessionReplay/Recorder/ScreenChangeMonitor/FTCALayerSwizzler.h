//
//  FTCALayerSwizzler.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
NS_ASSUME_NONNULL_BEGIN

@protocol FTCALayerObserver <NSObject>
- (void)layerDidDisplay:(CALayer *)layer;
- (void)layerDidDraw:(CALayer *)layer inContext:(CGContextRef)context;
- (void)layerDidLayoutSublayers:(CALayer *)layer;
@end

@interface FTCALayerSwizzler : NSObject
- (instancetype)initWithObserver:(id<FTCALayerObserver>)observer;
- (void)swizzleIfNeeded;
@end

NS_ASSUME_NONNULL_END
