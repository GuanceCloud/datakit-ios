//
//  FTAutoTrackActionPublisher.m
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import "FTAutoTrackActionPublisher.h"
#import "FTConstants.h"

@interface FTAutoTrackActionPublisher ()
@property (nonatomic, strong, nullable) FTActionTrackingHandler actionTrackingHandler;
@property (nonatomic, weak, nullable) id<FTRumDatasProtocol> addRumDatasDelegate;
@property (nonatomic, strong) FTAutoTrackHeatmapResolver *heatmapResolver;
@end

@implementation FTAutoTrackActionPublisher

- (instancetype)initWithActionTrackingHandler:(FTActionTrackingHandler)actionTrackingHandler
                          addRumDatasDelegate:(id<FTRumDatasProtocol>)addRumDatasDelegate
                              heatmapResolver:(FTAutoTrackHeatmapResolver *)heatmapResolver {
    self = [super init];
    if (self) {
        _actionTrackingHandler = actionTrackingHandler;
        _addRumDatasDelegate = addRumDatasDelegate;
        _heatmapResolver = heatmapResolver;
    }
    return self;
}

#if TARGET_OS_IOS
- (void)publishUIKitActionWithTargetView:(UIView *)targetView
                       heatmapTargetView:(UIView *)heatmapTargetView
                        locationResolver:(FTHeatmapLocationResolver)locationResolver {
    if (self.actionTrackingHandler && [self.actionTrackingHandler respondsToSelector:@selector(rumActionWithTargetView:)]) {
        FTRUMAction *action = [self.actionTrackingHandler rumActionWithTargetView:targetView];
        if (action == nil) {
            return;
        }
        FTHeatmapAttributes *heatmapAttributes = [self.heatmapResolver heatmapAttributesForActionTargetView:targetView heatmapTargetView:heatmapTargetView ?: targetView locationResolver:locationResolver];
        [self publishAction:action heatmapAttributes:heatmapAttributes];
    }
}

- (void)publishSwiftUIActionWithName:(NSString *)actionName property:(NSDictionary *)property {
    if (actionName.length == 0) {
        return;
    }
    if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]) {
        [self.addRumDatasDelegate startAction:actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:property];
    }
}
#endif

#if TARGET_OS_TV
- (void)publishTVActionWithPressType:(UIPressType)type view:(UIView *)view {
    if (self.actionTrackingHandler && [self.actionTrackingHandler respondsToSelector:@selector(rumActionWithPressType:targetView:)]) {
        FTRUMAction *action = [self.actionTrackingHandler rumActionWithPressType:type targetView:view];
        if (action == nil) {
            return;
        }
        [self publishAction:action heatmapAttributes:nil];
    }
}
#endif

- (void)publishAction:(FTRUMAction *)action heatmapAttributes:(FTHeatmapAttributes *)heatmapAttributes {
    if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:heatmapAttributes:)]) {
        [self.addRumDatasDelegate startAction:action.actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:action.property heatmapAttributes:heatmapAttributes];
    } else if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]) {
        [self.addRumDatasDelegate startAction:action.actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:action.property];
    }
}

@end
