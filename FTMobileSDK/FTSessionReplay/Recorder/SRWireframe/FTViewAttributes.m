//
//  FTViewAttributes.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTViewAttributes.h"
@implementation FTSRContext
@end

@implementation FTViewAttributes
-(instancetype)initWithFrameInRootView:(CGRect)frame view:(UIView *)view{
    self = [super init];
    if(self){
        self.frame = frame;
        self.alpha = view.alpha;
        self.backgroundColor = view.backgroundColor.CGColor;
        self.layerBorderColor = view.layer.borderColor;
        self.layerBorderWidth = view.layer.borderWidth;
        self.layerCornerRadius = view.layer.cornerRadius;
        self.isHidden = view.isHidden;
        self.intrinsicContentSize = view.intrinsicContentSize;
    }
    return self;
}
-(BOOL)isVisible{
    return  !self.isHidden && self.alpha > 0 && !CGRectEqualToRect(self.frame, CGRectZero);
}
-(BOOL)hasAnyAppearance{
    CGFloat borderAlpha = CGColorGetAlpha(self.layerBorderColor);
    BOOL hasBorderAppearance = self.layerBorderWidth > 0 && borderAlpha > 0 ;
    
    CGFloat fillAlpha = CGColorGetAlpha(self.backgroundColor);
    BOOL hasFillAppearance = fillAlpha > 0 ;
    return self.isVisible && (hasBorderAppearance || hasFillAppearance);
}
-(BOOL)isTranslucent{
    return  !self.isVisible || self.alpha < 1 || ((!self.backgroundColor? 0 : CGColorGetAlpha(self.backgroundColor)) < 1);
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTViewAttributes *attributes = [[[self class] allocWithZone:zone] init];
    attributes.frame = self.frame;
    attributes.alpha = self.alpha;
    attributes.backgroundColor = self.backgroundColor;
    attributes.layerBorderColor = self.layerBorderColor;
    attributes.layerBorderWidth = self.layerBorderWidth;
    attributes.layerCornerRadius = self.layerCornerRadius;
    attributes.isHidden = self.isHidden;
    attributes.intrinsicContentSize = self.intrinsicContentSize;
    return attributes;
}
@end
