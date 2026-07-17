//
//  FTUINavigationBarRecorder.m
//  SessionReplay
//
//  Created by hulilei on 2023/8/24.
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
    builder.color = [FTSRColorSnapshot snapshotWithColor:[self inferNavigationBarColor:bar] traitCollection:bar.traitCollection];
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
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder{
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect clip:self.attributes.clip backgroundColor:self.color.hexString cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:[[UIColor lightGrayColor] colorWithAlphaComponent:0.5].CGColor] width:1];
    return @[wireframe];
}
@end

#endif
