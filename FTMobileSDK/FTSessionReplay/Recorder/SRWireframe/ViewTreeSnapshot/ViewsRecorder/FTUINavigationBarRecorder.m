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
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTUINavigationBarRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UINavigationBar.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UINavigationBar *bar = (UINavigationBar *)view;
    FTUINavigationBarBuilder *builder = [[FTUINavigationBarBuilder alloc]init];
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:bar nodeRecorder:self];
    builder.color = [self inferNavigationBarColor:bar];
    builder.wireframeRect = [self inferNavigationBarFrame:bar context:context];
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyRecord];
    element.nodes = @[builder];
    return element;
}
- (UIColor *)inferNavigationBarColor:(UINavigationBar *)bar{
    if (@available(iOS 15.0, *)) {
        // scrollEdgeAppearance
        if(bar.standardAppearance.backgroundColor){
            return bar.standardAppearance.backgroundColor;
        }
    }
    if(bar.barTintColor){
        return bar.barTintColor;
    }
    if (@available(iOS 13.0, *)) {
        switch ([UITraitCollection currentTraitCollection].userInterfaceStyle) {
            case UIUserInterfaceStyleLight:
                return [UIColor whiteColor];
            case UIUserInterfaceStyleDark:
                return [UIColor blackColor];
            default:
                return [UIColor whiteColor];
        }
    }
    return UIColor.whiteColor;
}
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
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect backgroundColor:[FTSRUtils colorHexString:self.color.CGColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:[[UIColor lightGrayColor] colorWithAlphaComponent:0.5].CGColor] width:1];
    return @[wireframe];
}
@end
