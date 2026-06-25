//
//  FTAutoTrackHeatmapResolver.h
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTAutoTrackHandler.h"
#import "FTHeatmap.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTAutoTrackHeatmapResolver : NSObject

- (instancetype)init;
- (instancetype)initWithRegistry:(nullable id<FTHeatmapIdentifierRegistry>)registry NS_DESIGNATED_INITIALIZER;

- (nullable FTHeatmapAttributes *)heatmapAttributesForActionTargetView:(UIView *)actionTargetView
                                                      heatmapTargetView:(UIView *)heatmapTargetView
                                                       locationResolver:(FTHeatmapLocationResolver)locationResolver;

@end

NS_ASSUME_NONNULL_END
