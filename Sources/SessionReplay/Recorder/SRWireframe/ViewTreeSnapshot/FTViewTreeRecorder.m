//
//  FTViewTreeRecorder.m
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
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTViewTreeRecorder.h"
#import "FTViewAttributes.h"
#import "FTSRViewID.h"
#import "FTSRNodeWireframesBuilder.h"
#import "FTViewTreeRecordingContext.h"
#if TARGET_OS_IOS
#import "UIView+FTSRPrivacy.h"
#elif TARGET_OS_OSX
#import "NSView+FTSRPrivacy.h"
#endif
#import "FTSessionReplayPrivacyOverrides+Extension.h"
#import "FTSessionReplayCoreImports.h"

@interface FTHeatmapNodeWireframesBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) id<FTSRNodeWireframesBuilder> wrappedBuilder;
@property (nonatomic, strong, readonly) FTHeatmapIdentifier *heatmapIdentifier;
- (instancetype)initWithBuilder:(id<FTSRNodeWireframesBuilder>)builder heatmapIdentifier:(FTHeatmapIdentifier *)heatmapIdentifier;
@end

@implementation FTHeatmapNodeWireframesBuilder
- (instancetype)initWithBuilder:(id<FTSRNodeWireframesBuilder>)builder heatmapIdentifier:(FTHeatmapIdentifier *)heatmapIdentifier {
    self = [super init];
    if (self) {
        _wrappedBuilder = builder;
        _heatmapIdentifier = heatmapIdentifier;
    }
    return self;
}
- (FTViewAttributes *)attributes {
    return [self.wrappedBuilder attributes];
}
- (CGRect)wireframeRect {
    return [self.wrappedBuilder wireframeRect];
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    return [self.wrappedBuilder buildWireframesWithBuilder:builder];
}
@end

@implementation FTViewTreeRecorder

- (void)record:(NSMutableArray *)nodes view:(FTSRPlatformView *)view context:(FTViewTreeRecordingContext *)context{
    [self record:nodes view:view context:context typeIndex:0];
}
- (void)record:(NSMutableArray *)nodes view:(FTSRPlatformView *)view context:(FTViewTreeRecordingContext *)context typeIndex:(NSInteger)typeIndex{
    [self recordRecursively:nodes view:view context:context overrides:view.sessionReplayPrivacyOverrides typeIndex:typeIndex];
}
- (void)recordRecursively:(NSMutableArray *)nodes view:(FTSRPlatformView *)view context:(FTViewTreeRecordingContext *)context overrides:(PrivacyOverrides *)overrides typeIndex:(NSInteger)typeIndex{
    FTViewTreeRecordingContext *newContext = [context copy];
    if (newContext.heatmapCache) {
        [newContext.nodePath addObject:[self heatmapPathComponentForView:view typeIndex:typeIndex]];
    }
    #if TARGET_OS_IOS
    if([view.nextResponder isKindOfClass:UIViewController.class]){
        UIViewController *viewController = (UIViewController *)view.nextResponder;
        [newContext.viewControllerContext setParentTypeWithViewController:viewController];
        newContext.viewControllerContext.isRootView = view == viewController.view;
    }else{
        newContext.viewControllerContext.isRootView = NO;
    }
    CGRect frame = [view convertRect:view.bounds toCoordinateSpace:newContext.coordinateSpace];
    BOOL clipsToBounds = view.clipsToBounds;
    #elif TARGET_OS_OSX
    newContext.viewControllerContext.isRootView = NO;
    CGRect convertedFrame = [view convertRect:view.bounds toView:newContext.coordinateSpace];
    CGRect frame = convertedFrame;
    if (!newContext.coordinateSpace.isFlipped) {
        frame.origin.y = NSHeight(newContext.coordinateSpace.bounds) - CGRectGetMaxY(convertedFrame);
    }
    BOOL clipsToBounds = [view isKindOfClass:NSClipView.class] || view.layer.masksToBounds;
    #endif
    if(clipsToBounds){
        newContext.clip = CGRectIntersection(frame, newContext.clip);
    }
    FTViewAttributes *attribute = [[FTViewAttributes alloc]initWithView:view frameInRootView:frame clip:newContext.clip overrides:overrides];
    FTSRNodeSemantics *semantics = [self nodeSemantics:view context:newContext attribute:attribute];
    if(semantics.nodes.count>0){
        [nodes addObjectsFromArray:[self heatmapNodesFromNodes:semantics.nodes view:view context:newContext]];
    }
    switch (semantics.subtreeStrategy) {
        case NodeSubtreeStrategyRecord:
        {
            NSArray<NSNumber *> *typeIndices = [self typeIndicesForSubviews:view.subviews];
            for (NSUInteger index = 0; index < view.subviews.count; index++) {
                FTSRPlatformView *subView = view.subviews[index];
                PrivacyOverrides *privacy = [PrivacyOverrides mergeChild:subView.sessionReplayPrivacyOverrides parent:overrides];
                [self recordRecursively:nodes view:subView context:newContext overrides:privacy typeIndex:[typeIndices[index] integerValue]];
            }
            break;
        }
        case NodeSubtreeStrategyIgnore:
            
            break;
    }
}

- (FTSRNodeSemantics *)nodeSemantics:(FTSRPlatformView *)view context:(FTViewTreeRecordingContext *)context attribute:(FTViewAttributes *)attribute{
    FTSRNodeSemantics *semantics = [FTUnknownElement constant];
    for (id<FTSRWireframesRecorder> recorder in self.nodeRecorders) {
        FTSRNodeSemantics *nextSemantics = [recorder recorder:view attributes:attribute context:context];
        if(nextSemantics){
            if(nextSemantics.importance >= semantics.importance){
                semantics = nextSemantics;
                if(nextSemantics.importance == INT_MAX){
                    break;
                }
            }
        }
    }
    return semantics;
}
- (NSArray<id<FTSRNodeWireframesBuilder>> *)heatmapNodesFromNodes:(NSArray<id<FTSRNodeWireframesBuilder>> *)nodes view:(FTSRPlatformView *)view context:(FTViewTreeRecordingContext *)context {
    if (!context.heatmapCache || context.recorder.viewPath.length == 0) {
        return nodes;
    }
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
    FTHeatmapIdentifier *identifier = [[FTHeatmapIdentifier alloc]initWithElementPath:context.nodePath viewName:context.recorder.viewPath bundleIdentifier:bundleIdentifier];
    NSValue *objectIdentifier = [FTHeatmapIdentifier objectIdentifierForObject:view];
    if (objectIdentifier) {
        context.heatmapCache.identifiers[objectIdentifier] = identifier;
    }
    NSMutableArray<id<FTSRNodeWireframesBuilder>> *wrappedNodes = [NSMutableArray arrayWithCapacity:nodes.count];
    for (id<FTSRNodeWireframesBuilder> node in nodes) {
        [wrappedNodes addObject:[[FTHeatmapNodeWireframesBuilder alloc]initWithBuilder:node heatmapIdentifier:identifier]];
    }
    return wrappedNodes;
}
- (NSString *)heatmapPathComponentForView:(FTSRPlatformView *)view typeIndex:(NSInteger)typeIndex {
    #if TARGET_OS_IOS
    if (view.accessibilityIdentifier.length > 0) {
        return view.accessibilityIdentifier;
    }
    #elif TARGET_OS_OSX
    if (view.identifier.length > 0) {
        return view.identifier;
    }
    #endif
    return [NSString stringWithFormat:@"cls:%@#%ld", NSStringFromClass(view.class), (long)typeIndex];
}
- (NSArray<NSNumber *> *)typeIndicesForSubviews:(NSArray<FTSRPlatformView *> *)subviews {
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    NSMutableArray<NSNumber *> *indices = [NSMutableArray arrayWithCapacity:subviews.count];
    for (FTSRPlatformView *subview in subviews) {
        NSString *className = NSStringFromClass(subview.class);
        NSInteger index = [counts[className] integerValue];
        [indices addObject:@(index)];
        counts[className] = @(index + 1);
    }
    return indices;
}
@end

#endif
