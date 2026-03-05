//
//  FTCALayerChange.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/3.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_OPTIONS(NSUInteger, FTCALayerChangeAspect) {
    FTCALayerChangeAspectDisplay = 1 << 0,
    FTCALayerChangeAspectDraw    = 1 << 1,
    FTCALayerChangeAspectLayout  = 1 << 2
};

@interface FTCALayerChange : NSObject
@property (nonatomic, weak, readonly) CALayer *layer;
@property (nonatomic, assign) FTCALayerChangeAspect aspects;

- (instancetype)initWithLayer:(CALayer *)layer aspects:(FTCALayerChangeAspect)aspects;
@end

NS_ASSUME_NONNULL_END
