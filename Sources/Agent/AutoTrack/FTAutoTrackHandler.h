//
//  FTTrack.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/11/27.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTRumDatasProtocol.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#import "FTAutoTrackProperty.h"
#import "FTViewTrackingHandler.h"
#import "FTActionTrackingHandler.h"
#endif
NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_IOS || TARGET_OS_TV
@class FTDisplayRateMonitor;
@protocol FTHeatmapIdentifierRegistry;
typedef CGPoint (^FTHeatmapLocationResolver)(UIView *view);
@protocol FTUIViewControllerHandler <NSObject>
-(void)notify_viewDidAppear:(UIViewController *)viewController animated:(BOOL)animated;
-(void)notify_viewDidDisappear:(UIViewController *)viewController animated:(BOOL)animated;
@end

@protocol FTUIEventHandler <NSObject>
-(void)notify_sendAction:(UIView *)view heatmapTargetView:(nullable UIView *)heatmapTargetView locationResolver:(nullable FTHeatmapLocationResolver)locationResolver;
-(void)notify_sendActionWithPressType:(UIPressType)type view:(UIView *)view;
#if TARGET_OS_IOS
-(void)notify_swiftUIActionWithName:(NSString *)actionName property:(nullable NSDictionary *)property;
#endif
@end
/// View and Action collection class
@interface FTAutoTrackHandler : NSObject

/// Handle ViewController lifecycle rum: startView, stopView
@property (nonatomic, weak, nullable) id<FTUIViewControllerHandler> viewControllerHandler;

@property (nonatomic, weak, nullable) id<FTUIEventHandler> actionHandler;

@property (nonatomic, weak, nullable, readonly) id<FTRumDatasProtocol> addRumDatasDelegate;
@property (nonatomic, strong, nullable, readonly) FTViewTrackingHandler uiKitViewTrackingHandler;
@property (nonatomic, strong, nullable, readonly) FTActionTrackingHandler actionTrackingHandler;

/// Singleton
+ (instancetype)sharedInstance;

/// Enable collection
/// - Parameters:
///   - enable: Whether to collect View data
///   - enable: Whether to collect Action data
-(void)startWithTrackView:(BOOL)enable
                   action:(BOOL)enable
      addRumDatasDelegate:(id<FTRumDatasProtocol>)delegate
              viewHandler:(nullable FTViewTrackingHandler)viewHandler
       swiftUIViewHandler:(nullable id<FTSwiftUIViewTrackingHandler>)swiftUIViewHandler
            actionHandler:(nullable FTActionTrackingHandler)actionHandler
           displayMonitor:(nullable FTDisplayRateMonitor *)displayMonitor;

-(void)startWithTrackView:(BOOL)enable
                   action:(BOOL)enable
      addRumDatasDelegate:(id<FTRumDatasProtocol>)delegate
              viewHandler:(nullable FTViewTrackingHandler)viewHandler
       swiftUIViewHandler:(nullable id<FTSwiftUIViewTrackingHandler>)swiftUIViewHandler
            actionHandler:(nullable FTActionTrackingHandler)actionHandler
           displayMonitor:(nullable FTDisplayRateMonitor *)displayMonitor
heatmapIdentifierRegistry:(nullable id<FTHeatmapIdentifierRegistry>)heatmapIdentifierRegistry;

-(void)shutDown;
@end
#elif TARGET_OS_OSX
/// View and Action collection class for macOS AppKit automatic tracking.
@interface FTAutoTrackHandler : NSObject

@property (nonatomic, weak, nullable, readonly) id<FTRumDatasProtocol> addRumDatasDelegate;

/// Singleton
+ (instancetype)sharedInstance;

/// Enable macOS AppKit automatic View and Action collection.
/// - Parameters:
///   - trackView: Whether to collect Window lifecycle as View data.
///   - trackAction: Whether to collect AppKit target/action click data.
- (void)startWithTrackView:(BOOL)trackView
                    action:(BOOL)trackAction
       addRumDatasDelegate:(id<FTRumDatasProtocol>)delegate;

- (void)shutDown;
@end
#endif

NS_ASSUME_NONNULL_END
