//
//  FTAutoTrackActionPublisher.h
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
#endif
