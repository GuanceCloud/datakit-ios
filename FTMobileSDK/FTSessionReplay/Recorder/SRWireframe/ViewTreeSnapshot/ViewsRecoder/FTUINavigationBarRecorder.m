//
//  FTUINavigationBarRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUINavigationBarRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTUINavigationBarRecorder
-(id<FTSRNodeSemantics>)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UINavigationBar.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UINavigationBar *bar = (UINavigationBar *)view;
    FTUINavigationBarBuilder *builder = [[FTUINavigationBarBuilder alloc]init];
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:bar];
    builder.color = [self inferNavigationBarColor:bar];
    builder.wireframeRect = [self inferNavigationBarFrame:bar context:context];
    
    FTSpecificElement *element = [[FTSpecificElement alloc]init];
    element.subtreeStrategy = NodeSubtreeStrategyRecord;
    element.nodes = @[builder];
    return element;
}
- (CGColorRef )inferNavigationBarColor:(UINavigationBar *)bar{
    if (@available(iOS 15.0, *)) {
        // scrollEdgeAppearance
        if(bar.standardAppearance.backgroundColor){
            return bar.standardAppearance.backgroundColor.CGColor;
        }
    }
    if(bar.barTintColor){
        return bar.barTintColor.CGColor;
    }
    if (@available(iOS 13.0, *)) {
        switch ([UITraitCollection currentTraitCollection].userInterfaceStyle) {
            case UIUserInterfaceStyleLight:
                return [UIColor whiteColor].CGColor;
            case UIUserInterfaceStyleDark:
                return [UIColor blackColor].CGColor;
            default:
                return [UIColor whiteColor].CGColor;
        }
    }
    return UIColor.whiteColor.CGColor;
}
// TODO: 确认：子视图的 frame 是否有必要添加到 bar 的 frame 上
- (CGRect)inferNavigationBarFrame:(UINavigationBar *)bar context:(FTViewTreeRecordingContext *)context{
    CGRect newRect = bar.frame;
    for (UIView *view in bar.subviews) {
        CGRect subViewRect = [view convertRect:view.frame toCoordinateSpace:context.coordinateSpace];
        newRect = CGRectUnion(newRect, subViewRect);
    }
    return newRect;
}
@end
@implementation FTUINavigationBarBuilder
- (NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect backgroundColor:[FTSRUtils colorHexString:self.color] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:[UIColor grayColor].CGColor] width:1];
    return @[wireframe];
}
@end
