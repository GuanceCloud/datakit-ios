//
//  FTAutoTrackHeatmapResolver.m
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import "FTAutoTrackHeatmapResolver.h"
#import "UIView+FTAutoTrack.h"

static NSInteger const FTHeatmapFallbackMaxVisitedViews = 100;

@interface FTAutoTrackHeatmapResolver ()
@property (nonatomic, strong, nullable) id<FTHeatmapIdentifierRegistry> registry;
@end

@implementation FTAutoTrackHeatmapResolver

- (instancetype)init {
    return [self initWithRegistry:nil];
}

- (instancetype)initWithRegistry:(id<FTHeatmapIdentifierRegistry>)registry {
    self = [super init];
    if (self) {
        _registry = registry;
    }
    return self;
}

- (FTHeatmapAttributes *)heatmapAttributesForActionTargetView:(UIView *)actionTargetView
                                            heatmapTargetView:(UIView *)heatmapTargetView
                                             locationResolver:(FTHeatmapLocationResolver)locationResolver {
    if (!heatmapTargetView || !locationResolver) {
        return nil;
    }
    id<FTHeatmapIdentifierRegistry> registry = self.registry;
    if (!registry || !registry.enableHeatmap) {
        return nil;
    }
    FTHeatmapAttributes *directAttributes = [self heatmapAttributesForView:heatmapTargetView registry:registry locationResolver:locationResolver];
    if (directAttributes) {
        return directAttributes;
    }
    if (!actionTargetView || ![self shouldFallbackHeatmapSearchForActionTargetView:actionTargetView]) {
        return nil;
    }
    CGPoint locationInActionTargetView = locationResolver(actionTargetView);
    if (!CGRectContainsPoint(actionTargetView.bounds, locationInActionTargetView)) {
        return nil;
    }
    NSInteger remainingBudget = FTHeatmapFallbackMaxVisitedViews;
    UIView *matchedView = [self registeredHeatmapViewInView:actionTargetView point:locationInActionTargetView registry:registry remainingBudget:&remainingBudget];
    if (!matchedView) {
        return nil;
    }
    return [self heatmapAttributesForView:matchedView registry:registry locationResolver:locationResolver];
}

- (FTHeatmapAttributes *)heatmapAttributesForView:(UIView *)view
                                         registry:(id<FTHeatmapIdentifierRegistry>)registry
                                 locationResolver:(FTHeatmapLocationResolver)locationResolver {
    if (!view || !registry || !locationResolver) {
        return nil;
    }
    FTHeatmapIdentifier *viewIdentifier = [registry heatmapIdentifierForObject:view];
    if (!viewIdentifier) {
        return nil;
    }
    CGPoint location = locationResolver(view);
    return [[FTHeatmapAttributes alloc]initWithIdentifier:viewIdentifier size:view.bounds.size location:location];
}

- (UIView *)registeredHeatmapViewInView:(UIView *)view
                                  point:(CGPoint)point
                               registry:(id<FTHeatmapIdentifierRegistry>)registry
                        remainingBudget:(NSInteger *)remainingBudget {
    if (!view || !registry || !remainingBudget || *remainingBudget <= 0) {
        return nil;
    }
    (*remainingBudget)--;
    if (view.hidden || view.alpha <= 0.01 || CGRectIsEmpty(view.bounds) || !CGRectContainsPoint(view.bounds, point)) {
        return nil;
    }
    for (UIView *subview in [view.subviews reverseObjectEnumerator]) {
        CGPoint subviewPoint = [view convertPoint:point toView:subview];
        UIView *matchedView = [self registeredHeatmapViewInView:subview point:subviewPoint registry:registry remainingBudget:remainingBudget];
        if (matchedView) {
            return matchedView;
        }
        if (*remainingBudget <= 0) {
            return nil;
        }
    }
    return [registry heatmapIdentifierForObject:view] ? view : nil;
}

- (BOOL)shouldFallbackHeatmapSearchForActionTargetView:(UIView *)view {
    return [view isKindOfClass:UIControl.class] ||
    [view isKindOfClass:UITableViewCell.class] ||
    [view isKindOfClass:UICollectionViewCell.class] ||
    [view isAlertClick];
}

@end
