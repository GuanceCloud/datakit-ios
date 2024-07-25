//
//  FTUIStepperRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUIStepperRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTUIStepperRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:[UIStepper class]]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UIStepper *stepper = (UIStepper *)view;
    CGRect stepperFrame = CGRectMake(attributes.frame.origin.x, attributes.frame.origin.y, stepper.intrinsicContentSize.width, stepper.intrinsicContentSize.height);
    NSArray *wireframeIDs = [context.viewIDGenerator SRViewIDs:view size:5 nodeRecorder:self];
    BOOL isMasked = context.recorder.privacy.shouldMaskInputElements;

    FTUIStepperBuilder *builder = [[FTUIStepperBuilder alloc]init];
    builder.attributes = attributes;
    builder.isMinusEnabled = isMasked || stepper.minimumValue < stepper.value;
    builder.isPlusEnabled = isMasked || stepper.maximumValue > stepper.value;
    if (stepper.subviews.count>0){
        builder.cornerRadius = stepper.subviews.firstObject.layer.cornerRadius;
    }
    builder.wireframeRect = stepperFrame;
    builder.backgroundWireframeID = [wireframeIDs[0] intValue];
    builder.dividerWireframeID = [wireframeIDs[1] intValue];
    builder.minusWireframeID = [wireframeIDs[2] intValue];
    builder.plusHorizontalWireframeID = [wireframeIDs[3] intValue];
    builder.plusVerticalWireframeID = [wireframeIDs[4] intValue];
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

@interface FTUIStepperBuilder ()
@end

@implementation FTUIStepperBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRShapeWireframe *backgroundWireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.wireframeRect backgroundColor:[FTSystemColors tertiarySystemFillColor] cornerRadius:@(self.cornerRadius) opacity:nil];
    CGFloat verticalMargin = 6;
    CGRect dividerRect = CGRectMake(0, verticalMargin, 1, self.wireframeRect.size.height - 2*verticalMargin);
    dividerRect = FTCGRectPutInside(dividerRect,self.wireframeRect,HorizontalAlignmentCenter,VerticalAlignmentMiddle);
    FTSRShapeWireframe *divider = [[FTSRShapeWireframe alloc]initWithIdentifier:self.dividerWireframeID frame:dividerRect backgroundColor:[FTSystemColors placeholderTextColor] cornerRadius:nil opacity:nil];
    CGRect horizontalElementRect = CGRectMake(0, 0, 14, 2);
    CGRect verticalElementRect = CGRectMake(0, 0, 2, 14);
    CGRect leftButtonFrame, rightButtonFrame;
    CGRectDivide(self.wireframeRect, &leftButtonFrame, &rightButtonFrame, self.wireframeRect.size.width / 2,CGRectMinXEdge);
    
    FTSRShapeWireframe *minus = [[FTSRShapeWireframe alloc]initWithIdentifier:self.minusWireframeID frame:FTCGRectPutInside(horizontalElementRect, leftButtonFrame, HorizontalAlignmentCenter, VerticalAlignmentMiddle) backgroundColor:self.isMinusEnabled?[FTSystemColors labelColor]:[FTSystemColors placeholderTextColor]  cornerRadius:@(horizontalElementRect.size.height) opacity:nil];
    
    FTSRShapeWireframe *plusHorizontal = [[FTSRShapeWireframe alloc]initWithIdentifier:self.plusHorizontalWireframeID frame:FTCGRectPutInside(horizontalElementRect, rightButtonFrame, HorizontalAlignmentCenter, VerticalAlignmentMiddle) backgroundColor:self.isPlusEnabled?[FTSystemColors labelColor]:[FTSystemColors placeholderTextColor] cornerRadius:@(horizontalElementRect.size.height) opacity:nil];
    

    FTSRShapeWireframe *plusVertical = [[FTSRShapeWireframe alloc]initWithIdentifier:self.plusVerticalWireframeID frame:FTCGRectPutInside(verticalElementRect, rightButtonFrame, HorizontalAlignmentCenter, VerticalAlignmentMiddle) backgroundColor:self.isPlusEnabled?[FTSystemColors labelColor]:[FTSystemColors placeholderTextColor] cornerRadius:@(verticalElementRect.size.width) opacity:nil];
    return @[backgroundWireframe,divider,minus,plusHorizontal,plusVertical];
}
@end
