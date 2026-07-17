//
//  FTAutoTrackEventResolver.h
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV
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
#endif
