//
//  FTViewAttributes.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTViewAttributes.h"
#import "FTSRUtils.h"
@implementation FTSRContext
@end

@implementation FTViewAttributes
-(instancetype)initWithView:(UIView *)view frameInRootView:(CGRect)frame clip:(CGRect)clip overrides:(PrivacyOverrides *)overrides{
    self = [super init];
    if(self){
        self.frame = frame;
        self.clip = clip;
        self.alpha = view.alpha;
        self.backgroundColor = view.backgroundColor;
        self.layerBorderColor = view.layer.borderColor;
        self.layerBorderWidth = view.layer.borderWidth;
        self.layerCornerRadius = view.layer.cornerRadius;
        self.isHidden = view.isHidden;
        self.intrinsicContentSize = view.intrinsicContentSize;
        self.imagePrivacy = overrides.nImagePrivacy;
        self.textAndInputPrivacy = overrides.nTextAndInputPrivacy;
        self.hide = overrides.hide;
    }
    return self;
}
-(BOOL)isVisible{
    return  !self.isHidden && self.alpha > 0 && !CGRectEqualToRect(self.frame, CGRectZero) && !CGRectIsEmpty(CGRectIntersection(self.frame, self.clip));
}
-(BOOL)hasAnyAppearance{
    CGFloat borderAlpha = [FTSRUtils getCGColorAlpha:self.layerBorderColor];
    BOOL hasBorderAppearance = self.layerBorderWidth > 0 && borderAlpha > 0 ;
    
    CGFloat fillAlpha = [FTSRUtils getCGColorAlpha:self.backgroundColor.CGColor];
    BOOL hasFillAppearance = fillAlpha > 0 ;
    return self.isVisible && (hasBorderAppearance || hasFillAppearance);
}
-(BOOL)isTranslucent{
    return  !self.isVisible || self.alpha < 1 || ([FTSRUtils getCGColorAlpha:self.backgroundColor.CGColor] < 1);
}
-(FTTextAndInputPrivacyLevel)resolveTextAndInputPrivacyLevel:(FTSRContext *)context{
    if (self.textAndInputPrivacy != nil) {
        return (FTTextAndInputPrivacyLevel)[self.textAndInputPrivacy intValue];
    }
    return context.textAndInputPrivacy;
}
-(FTImagePrivacyLevel)resolveImagePrivacyLevel:(FTSRContext *)context{
    if (self.imagePrivacy != nil) {
        return (FTImagePrivacyLevel)[self.imagePrivacy intValue];
    }
    return context.imagePrivacy;
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
