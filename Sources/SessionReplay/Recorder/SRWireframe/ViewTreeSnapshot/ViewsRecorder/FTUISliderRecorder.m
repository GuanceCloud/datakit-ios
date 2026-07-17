//
//  FTUISliderRecorder.m
//  SessionReplay
//
//  Created by hulilei on 2023/8/28.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTUISliderRecorder.h"
#import <CoreGraphics/CoreGraphics.h>
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
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
    builder.isMasked = [FTSRTextObfuscatingFactory shouldMaskInputElements:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
    builder.backgroundWireframeID = [ids[0] intValue];
    builder.minTrackWireframeID = [ids[1] intValue];
    builder.maxTrackWireframeID = [ids[2] intValue];
    builder.thumbWireframeID = [ids[3] intValue];
    builder.isEnabled = slider.isEnabled;
    builder.min = slider.minimumValue;
    builder.max = slider.maximumValue;
    builder.value = slider.value;
    builder.minTrackTintColor = [FTSRColorSnapshot snapshotWithColor:slider.minimumTrackTintColor?slider.minimumTrackTintColor:slider.tintColor traitCollection:slider.traitCollection];
    builder.maxTrackTintColor = [FTSRColorSnapshot snapshotWithColor:slider.maximumTrackTintColor traitCollection:slider.traitCollection];
    builder.thumbTintColor = [FTSRColorSnapshot snapshotWithColor:slider.thumbTintColor traitCollection:slider.traitCollection];
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end


@implementation FTUISliderBuilder

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder{
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
                                           clip:self.attributes.clip
                                           backgroundColor:[FTSystemColors tertiarySystemFillColorStr]
                                           cornerRadius:@(self.wireframeRect.size.width/2)
                                           opacity:self.isEnabled?@(self.attributes.alpha) : @(0.5)];
    
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID attributes:self.attributes];
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
                                          clip:self.attributes.clip
                                          backgroundColor:self.isEnabled?(self.thumbTintColor.hexString?:[FTSRUtils colorHexString:[UIColor whiteColor].CGColor]):[FTSystemColors tertiarySystemBackgroundColorStr]
                                          cornerRadius:@(cornerRadius)
                                          opacity:@(self.attributes.alpha)];
    thumbWireframe.border = [[FTSRShapeBorder alloc]
                             initWithColor:self.isEnabled?[FTSystemColors secondarySystemFillColorStr]:[FTSystemColors tertiarySystemBackgroundColorStr]
                             width:1];
    
    CGRect slice, remainder;
    CGRectDivide(left, &slice, &remainder, 3,CGRectMinYEdge);
    
    CGRect realL = FTCGRectPutInside(slice, left, HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    
    CGRectDivide(right, &slice, &remainder, 3,CGRectMinYEdge);
    CGRect realR = FTCGRectPutInside(slice, right, HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    FTSRShapeWireframe *lWireframe = [[FTSRShapeWireframe alloc]
                                      initWithIdentifier:self.minTrackWireframeID 
                                      frame:realL
                                      clip:self.attributes.clip
                                      backgroundColor:self.minTrackTintColor.hexString?:[FTSystemColors tintColorStr]
                                      cornerRadius:@(0)
                                      opacity:self.isEnabled?@(self.attributes.alpha):@(0.5)];
    FTSRShapeWireframe *rWireframe = [[FTSRShapeWireframe alloc]
                                      initWithIdentifier:self.maxTrackWireframeID
                                      frame:realR
                                      clip:self.attributes.clip
                                      backgroundColor:self.maxTrackTintColor.hexString?:[FTSystemColors tertiarySystemFillColorStr]
                                      cornerRadius:@(0)
                                      opacity:self.isEnabled?@(self.attributes.alpha):@(0.5)];
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]
                                          initWithIdentifier:self.backgroundWireframeID
                                          attributes:self.attributes];
        return @[background,lWireframe,rWireframe,thumbWireframe];
    }
    return @[lWireframe,rWireframe,thumbWireframe];
}

@end

#endif
