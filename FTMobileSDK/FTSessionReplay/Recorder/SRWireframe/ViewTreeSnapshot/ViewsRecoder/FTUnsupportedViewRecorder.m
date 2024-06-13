//
//  FTUnsupportedViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTUnsupportedViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import <WebKit/WebKit.h>
#import "FTViewTreeRecordingContext.h"
@implementation FTUnsupportedViewRecorder

- (id<FTSRNodeSemantics>)recorder:(nonnull UIView *)view attributes:(nonnull FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context { 
    // 是否是不采集的控制器
    if([context.viewControllerContext isRootView:ViewControllerTypeSafari]||[context.viewControllerContext isRootView:ViewControllerTypeActivity]||[context.viewControllerContext isRootView:ViewControllerTypeSwiftUI]){
        return nil;
    }
    // 是否是不采集的View
    if ([view isKindOfClass:[UIProgressView class]] || [view isKindOfClass:[UIActivityIndicatorView class]]){
        return nil;
    }
    // View 是不是不可见
    if (attributes.isVisible){
        FTInvisibleElement *element = [[FTInvisibleElement alloc]init];
        element.subtreeStrategy = NodeSubtreeStrategyIgnore;
        return element;
    }
    FTUnsupportedViewBuilder *builder = [[FTUnsupportedViewBuilder alloc]init];
    builder.wireframeRect = view.frame;
    builder.wireframeID = [context.viewIDGenerator SRViewID:view];
    builder.unsupportedClassName = context.viewControllerContext.name?:NSStringFromClass(view.class);
    builder.attributes = attributes;
    FTSpecificElement *element = [[FTSpecificElement alloc]init];
    element.nodes = @[builder];
    return element;
}
@end

@implementation FTUnsupportedViewBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRPlaceholderWireframe *wireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.wireframeID frame:self.attributes.frame label:self.unsupportedClassName];
    return @[wireframe];
}

@end
