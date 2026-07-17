//
//  FTUnsupportedViewRecorder.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/13.
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

#import "FTUnsupportedViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
@interface FTUnsupportedViewRecorder()
@property (nonatomic, assign) BOOL swiftUIEnabled;
@end
@implementation FTUnsupportedViewRecorder
-(instancetype)init{
    return [self initWithSwiftUIEnabled:NO];
}
-(instancetype)initWithSwiftUIEnabled:(BOOL)swiftUIEnabled{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _swiftUIEnabled = swiftUIEnabled;
    }
    return self;
}
- (FTSRNodeSemantics *)recorder:(nonnull UIView *)view attributes:(nonnull FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context {
    // Whether it's a controller that shouldn't be collected
    BOOL isUnsupportedRootView = [context.viewControllerContext isRootView:ViewControllerTypeSafari] || [context.viewControllerContext isRootView:ViewControllerTypeActivity] || (!self.swiftUIEnabled && [context.viewControllerContext isRootView:ViewControllerTypeSwiftUI]);
    if(isUnsupportedRootView){
        
        // Whether View is invisible
        if (!attributes.isVisible){
            FTInvisibleElement *element = [[FTInvisibleElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
            return element;
        }
        FTUnsupportedViewBuilder *builder = [[FTUnsupportedViewBuilder alloc]init];
        builder.wireframeRect = view.frame;
        builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
        builder.unsupportedClassName = context.viewControllerContext.name?:NSStringFromClass(view.class);
        builder.attributes = attributes;
        FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
        element.nodes = @[builder];
        return element;
    }
    return nil;
}
@end

@implementation FTUnsupportedViewBuilder

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder{
    FTSRPlaceholderWireframe *wireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.wireframeID frame:self.attributes.frame label:self.unsupportedClassName];
    wireframe.clip = [[FTSRContentClip alloc] initWithFrame:self.attributes.frame clip:self.attributes.clip];
    return @[wireframe];
}

@end

#endif
