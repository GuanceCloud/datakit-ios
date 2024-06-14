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
-(id<FTSRNodeSemantics>)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:[UIStepper class]]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UIStepper *stepper = (UIStepper *)view;
    CGRect stepperFrame = CGRectMake(attributes.frame.origin.x, attributes.frame.origin.y, stepper.intrinsicContentSize.width, stepper.intrinsicContentSize.height);
    NSArray *wireframeIDs = [context.viewIDGenerator SRViewIDs:view size:5];
    FTUIStepperBuilder *builder = [[FTUIStepperBuilder alloc]init];
    builder.attributes = attributes;
    builder.isMinusEnabled = stepper.minimumValue < stepper.value;
    builder.isPlusEnabled = stepper.maximumValue > stepper.value;
    if (stepper.subviews.count>0){
        builder.cornerRadius = stepper.subviews.firstObject.layer.cornerRadius;
    }
    builder.wireframeRect = stepperFrame;
    builder.backgroundWireframeID = [wireframeIDs[0] intValue];
    builder.dividerWireframeID = [wireframeIDs[1] intValue];
    builder.minusWireframeID = [wireframeIDs[2] intValue];
    builder.plusHorizontalWireframeID = [wireframeIDs[3] intValue];
    builder.plusVerticalWireframeID = [wireframeIDs[4] intValue];
    
    FTSpecificElement *element = [[FTSpecificElement alloc]init];
    element.subtreeStrategy = NodeSubtreeStrategyIgnore;
    element.nodes = @[builder];
    return element;
}
@end

@interface FTUIStepperBuilder ()
@end

@implementation FTUIStepperBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRShapeWireframe *backgroundWireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.wireframeRect backgroundColor:[FTSystemColors systemFillColor] cornerRadius:@(self.cornerRadius) opacity:@(1)];
   
    CGRect dividerRect = FTCGRectFitWithContentMode(self.wireframeRect, CGSizeMake(2, 10), UIViewContentModeCenter);
    FTSRShapeWireframe *divider = [[FTSRShapeWireframe alloc]initWithIdentifier:self.dividerWireframeID frame:dividerRect backgroundColor:[FTSystemColors systemFillColor] cornerRadius:nil opacity:@(1)];

    CGRect leftButtonFrame, rightButtonFrame;
    CGRectDivide(self.wireframeRect, &leftButtonFrame, &rightButtonFrame, self.wireframeRect.size.width / 2,CGRectMinXEdge);
    CGRect leftRect = FTCGRectFitWithContentMode(leftButtonFrame, CGSizeMake(14, 2), UIViewContentModeCenter);
    FTSRShapeWireframe *left = [[FTSRShapeWireframe alloc]initWithIdentifier:self.minusWireframeID frame:leftRect backgroundColor:self.isMinusEnabled?[FTSystemColors labelColor]:[FTSystemColors placeholderTextColor] cornerRadius:nil opacity:@(1)];
    
    CGRect hRightRect = FTCGRectFitWithContentMode(rightButtonFrame, CGSizeMake(14, 2), UIViewContentModeCenter);
    CGRect vRightRect = FTCGRectFitWithContentMode(rightButtonFrame, CGSizeMake(2, 12), UIViewContentModeCenter);
    FTSRShapeWireframe *hRight = [[FTSRShapeWireframe alloc]initWithIdentifier:self.plusHorizontalWireframeID frame:hRightRect backgroundColor:self.isPlusEnabled?[FTSystemColors labelColor]:[FTSystemColors placeholderTextColor] cornerRadius:nil opacity:@(1)];
    FTSRShapeWireframe *vRight = [[FTSRShapeWireframe alloc]initWithIdentifier:self.plusVerticalWireframeID frame:vRightRect backgroundColor:self.isPlusEnabled?[FTSystemColors labelColor]:[FTSystemColors placeholderTextColor]  cornerRadius:nil opacity:@(1)];
    return @[backgroundWireframe,divider,left,hRight,vRight];
}
@end
