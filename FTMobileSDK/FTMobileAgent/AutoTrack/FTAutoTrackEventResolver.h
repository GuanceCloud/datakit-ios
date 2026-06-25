//
//  FTAutoTrackEventResolver.h
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTAutoTrackHandler.h"

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_IOS
@interface FTAutoTrackActionEvent : NSObject
@property (nonatomic, strong, readonly) UIView *actionTargetView;
@property (nonatomic, strong, readonly) UIView *heatmapTargetView;
@property (nonatomic, copy, readonly) FTHeatmapLocationResolver locationResolver;

- (instancetype)init NS_UNAVAILABLE;
@end
#endif

#if TARGET_OS_TV
@interface FTAutoTrackPressEvent : NSObject
@property (nonatomic, assign, readonly) UIPressType pressType;
@property (nonatomic, strong, readonly) UIView *targetView;

- (instancetype)init NS_UNAVAILABLE;
@end
#endif

@interface FTAutoTrackEventResolver : NSObject

#if TARGET_OS_IOS
+ (nullable FTAutoTrackActionEvent *)actionEventFromTouchEvent:(UIEvent *)event;
#endif

#if TARGET_OS_TV
+ (nullable FTAutoTrackPressEvent *)pressEventFromEvent:(UIEvent *)event;
#endif

@end

NS_ASSUME_NONNULL_END
