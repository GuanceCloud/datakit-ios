//
//  FTAutoTrackActionPublisher.h
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTActionTrackingHandler.h"
#import "FTRumDatasProtocol.h"
#import "FTAutoTrackHeatmapResolver.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTAutoTrackActionPublisher : NSObject

@property (nonatomic, strong, nullable, readonly) FTActionTrackingHandler actionTrackingHandler;
@property (nonatomic, weak, nullable, readonly) id<FTRumDatasProtocol> addRumDatasDelegate;
@property (nonatomic, strong, readonly) FTAutoTrackHeatmapResolver *heatmapResolver;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActionTrackingHandler:(nullable FTActionTrackingHandler)actionTrackingHandler
                          addRumDatasDelegate:(nullable id<FTRumDatasProtocol>)addRumDatasDelegate
                              heatmapResolver:(FTAutoTrackHeatmapResolver *)heatmapResolver NS_DESIGNATED_INITIALIZER;

#if TARGET_OS_IOS
- (void)publishUIKitActionWithTargetView:(UIView *)targetView
                       heatmapTargetView:(nullable UIView *)heatmapTargetView
                         locationResolver:(nullable FTHeatmapLocationResolver)locationResolver;

- (void)publishSwiftUIActionWithName:(NSString *)actionName property:(nullable NSDictionary *)property;
#endif

#if TARGET_OS_TV
- (void)publishTVActionWithPressType:(UIPressType)type view:(UIView *)view;
#endif

@end

NS_ASSUME_NONNULL_END
