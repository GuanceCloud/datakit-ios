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
#import "FTViewTreeRecordingContext.h"
@implementation FTUISliderRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UISlider.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UISlider *slider = (UISlider *)view;
    NSArray *ids = [context.viewIDGenerator SRViewIDs:slider size:4 nodeRecorder:self];
    FTUISliderBuilder *builder = [[FTUISliderBuilder alloc]init];
    builder.wireframeRect = attributes.frame;
    builder.attributes = attributes;
    builder.isMasked = context.recorder.privacy.shouldMaskInputElements;
    builder.backgroundWireframeID = [ids[0] intValue];
    builder.minTrackWireframeID = [ids[1] intValue];
    builder.maxTrackWireframeID = [ids[2] intValue];
    builder.thumbWireframeID = [ids[3] intValue];
    builder.isEnabled = slider.isEnabled;
    builder.min = slider.minimumValue;
    builder.max = slider.maximumValue;
    builder.value = slider.value;
    builder.minTrackTintColor = slider.minimumTrackTintColor.CGColor?slider.minimumTrackTintColor.CGColor:slider.tintColor.CGColor;
    builder.maxTrackTintColor = slider.maximumTrackTintColor.CGColor;
    builder.thumbTintColor = slider.thumbTintColor.CGColor;
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
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
    CGRect slice, remainder;
    CGRectDivide(self.wireframeRect, &slice, &remainder, 3, CGRectMinYEdge);
    CGRect trackFrame = FTCGRectPutInside(slice, self.wireframeRect, HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    FTSRShapeWireframe *sliderWireframe = [[FTSRShapeWireframe alloc]
                                           initWithIdentifier:self.minTrackWireframeID
                                           frame:trackFrame
                                           backgroundColor:[FTSystemColors tertiarySystemFillColor]
                                           cornerRadius:@(self.wireframeRect.size.width/2)
                                           opacity:self.isEnabled?@(self.attributes.alpha) : @(0.5)];
    
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.attributes.frame attributes:self.attributes];
        return @[background,sliderWireframe];
    }
    return @[sliderWireframe];
}
- (NSArray<FTSRWireframe *> *)createNoMaskWireframes{
    if(self.max<self.min){
        return @[];
    }
    float progress = (self.value - self.min) / ((self.max-self.min)*1.0) ;
    CGRect left, right;
    CGRectDivide(self.wireframeRect, &left, &right, self.wireframeRect.size.width*progress,CGRectMinXEdge);

    CGFloat cornerRadius = self.wireframeRect.size.height * 0.5;
    CGRect thumbFrame = CGRectMake(CGRectGetMaxX(left)-cornerRadius, CGRectGetMinY(left), self.wireframeRect.size.height, self.wireframeRect.size.height);
    
    FTSRShapeWireframe *thumbWireframe = [[FTSRShapeWireframe alloc]
                                          initWithIdentifier:self.thumbWireframeID
                                          frame:thumbFrame
                                          backgroundColor:self.isEnabled?(self.thumbTintColor?[FTSRUtils colorHexString:self.thumbTintColor]:[FTSRUtils colorHexString:[UIColor whiteColor].CGColor]):[FTSystemColors tertiarySystemBackgroundColor]
                                          cornerRadius:@(cornerRadius)
                                          opacity:@(self.attributes.alpha)];
    thumbWireframe.border = [[FTSRShapeBorder alloc]
                             initWithColor:self.isEnabled?[FTSystemColors secondarySystemFillColor]:[FTSystemColors tertiarySystemBackgroundColor]
                             width:1];
    
    CGRect slice, remainder;
    CGRectDivide(left, &slice, &remainder, 3,CGRectMinYEdge);
    
    CGRect realL = FTCGRectPutInside(slice, left, HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    
    CGRectDivide(right, &slice, &remainder, 3,CGRectMinYEdge);
    CGRect realR = FTCGRectPutInside(slice, right, HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    FTSRShapeWireframe *lWireframe = [[FTSRShapeWireframe alloc]
                                      initWithIdentifier:self.minTrackWireframeID 
                                      frame:realL
                                      backgroundColor:self.minTrackTintColor?[FTSRUtils
                                                                              colorHexString:self.minTrackTintColor]:[FTSystemColors tintColor]
                                      cornerRadius:@(0)
                                      opacity:self.isEnabled?@(self.attributes.alpha):@(0.5)];
    FTSRShapeWireframe *rWireframe = [[FTSRShapeWireframe alloc]
                                      initWithIdentifier:self.minTrackWireframeID
                                      frame:realR 
                                      backgroundColor:self.maxTrackTintColor?[FTSRUtils colorHexString:self.maxTrackTintColor]:[FTSystemColors tertiarySystemFillColor]
                                      cornerRadius:@(0)
                                      opacity:self.isEnabled?@(self.attributes.alpha):@(0.5)];
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]
                                          initWithIdentifier:self.backgroundWireframeID
                                          frame:self.attributes.frame
                                          attributes:self.attributes];
        return @[background,lWireframe,rWireframe,thumbWireframe];
    }
    return @[lWireframe,rWireframe,thumbWireframe];
}

@end
