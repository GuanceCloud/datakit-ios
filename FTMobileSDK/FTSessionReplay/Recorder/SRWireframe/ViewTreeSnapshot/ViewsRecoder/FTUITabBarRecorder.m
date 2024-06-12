//
//  FTUITabBarRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUITabBarRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
@implementation FTUITabBarRecorder
-(NSArray<id<FTSRWireframesBuilder>> *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTRecorderContext *)context{
    if(![view isKindOfClass:[UITabBar class]]){
        return nil;
    }
    UITabBar *tabBar = (UITabBar *)view;
    FTUITabBarBuilder *builder = [[FTUITabBarBuilder alloc]init];
    builder.color = [self inferTabBarColor:tabBar];
    builder.wireframeID = [context.viewIDGenerator SRViewID:tabBar];
    builder.wireframeRect = tabBar.frame;
    builder.attributes = attributes;
    return @[builder];
}
- (CGColorRef )inferTabBarColor:(UITabBar *)bar{
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
//  TODO: 确认：子视图的 frame 是否有必要添加到 bar 的 frame 上
- (CGRect)inferBarFrame:(UITabBar *)bar context:(FTRecorderContext *)context{
    CGRect newRect = bar.frame;
    for (UIView *view in bar.subviews) {
        CGRect subViewRect = [view convertRect:view.frame toView:context.rootView];
        newRect = CGRectUnion(newRect, subViewRect);
    }
    return newRect;
}
@end

@implementation FTUITabBarBuilder
- (NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect backgroundColor:[FTSRUtils colorHexString:self.color] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:[UIColor grayColor].CGColor] width:1];
    return @[wireframe];
}
@end
