//
//  FTUISliderRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUISliderRecorder.h"
#import <CoreGraphics/CoreGraphics.h>
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
@implementation FTUISliderRecorder
-(NSArray<id<FTSRWireframesBuilder>> *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTRecorderContext *)context{
    if(![view isKindOfClass:UISlider.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return nil;
    }
    UISlider *slider = (UISlider *)view;
    NSArray *ids = [context.viewIDGenerator SRViewIDs:view size:4];
    FTUISliderBuilder *builder = [[FTUISliderBuilder alloc]init];
    builder.attributes = attributes;
    builder.isMasked = context.recorder.privacy != FTSRPrivacyMaskNone;
    builder.backgroundWireframeID = [ids[0] intValue];
    builder.minTrackWireframeID = [ids[1] intValue];
    builder.maxTrackWireframeID = [ids[2] intValue];
    builder.thumbWireframeID = [ids[3] intValue];
    builder.isEnabled = slider.enabled;
    builder.min = slider.minimumValue;
    builder.max = slider.maximumValue;
    builder.value = slider.value;
    builder.minTrackTintColor = slider.minimumTrackTintColor.CGColor;
    builder.maxTrackTintColor = slider.maximumTrackTintColor.CGColor;
    builder.thumbTintColor = slider.thumbTintColor.CGColor;
    return @[builder];
}
@end


@implementation FTUISliderBuilder


/// slider - height:4
///          circle:28
- (NSArray<FTSRWireframe *> *)buildWireframes {
    if(self.isMasked){
        return [self createMaskWireframes];
    }else{
        return [self createNoMaskWireframes];
    }
}
- (NSArray<FTSRWireframe *> *)createMaskWireframes{
    CGRect slider = FTCGRectFitWithContentMode(self.wireframeRect, CGSizeMake(self.wireframeRect.size.width, 4), UIViewContentModeCenter);
    FTSRShapeWireframe *sliderWireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.minTrackWireframeID frame:slider backgroundColor:[FTSystemColors systemFillColor] cornerRadius:@(slider.size.width/2) opacity:self.isEnabled?@(self.attributes.alpha) : @(0.5)];
    
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.attributes.frame attributes:self.attributes];
        return @[background,sliderWireframe];
    }
    return @[sliderWireframe];
}
- (NSArray<FTSRWireframe *> *)createNoMaskWireframes{
    float progress = (self.value - self.min) / (self.max-self.min) ;
    CGRect left, right;
    CGRectDivide(self.wireframeRect, &left, &right, self.wireframeRect.size.width*progress,CGRectMinXEdge);

    CGFloat cornerRadius = self.wireframeRect.size.height / 2;
    CGRect thumbFrame = CGRectMake(CGRectGetMaxX(left)-cornerRadius, CGRectGetMinY(left), self.wireframeRect.size.height, self.wireframeRect.size.height);
    
    FTSRShapeWireframe *thumbWireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.thumbWireframeID frame:thumbFrame backgroundColor:[FTSRUtils colorHexString:self.thumbTintColor] cornerRadius:@(cornerRadius) opacity:@(self.attributes.alpha)];
    thumbWireframe.border = [[FTSRShapeBorder alloc]initWithColor:self.isEnabled?[FTSystemColors secondarySystemFillColor]:[FTSystemColors tertiarySystemFillColor] width:1];
    
    CGRect realL = FTCGRectFitWithContentMode(left, CGSizeMake(left.size.width, 4), UIViewContentModeCenter);
    CGRect realR = FTCGRectFitWithContentMode(right, CGSizeMake(right.size.width, 4), UIViewContentModeCenter);
    FTSRShapeWireframe *lWireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.minTrackWireframeID frame:realL backgroundColor:self.minTrackTintColor?[FTSRUtils colorHexString:self.minTrackTintColor]:[FTSystemColors tintColor] cornerRadius:nil opacity:self.isEnabled?@(self.attributes.alpha):@(0.5)];
    FTSRShapeWireframe *rWireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.minTrackWireframeID frame:realR backgroundColor:self.minTrackTintColor?[FTSRUtils colorHexString:self.maxTrackTintColor]:[FTSystemColors tertiarySystemFillColor] cornerRadius:nil opacity:self.isEnabled?@(self.attributes.alpha):@(0.5)];
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.attributes.frame attributes:self.attributes];
        return @[background,lWireframe,rWireframe,thumbWireframe];
    }
    return @[lWireframe,rWireframe,thumbWireframe];
}

@end
