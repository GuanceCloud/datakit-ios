//
//  FTTrack.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/11/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTRumDatasProtocol.h"
#import "FTAutoTrackProperty.h"
#import "FTRumConfig.h"
#import "FTViewTrackingHandler.h"
#import "FTActionTrackingHandler.h"
NS_ASSUME_NONNULL_BEGIN
@class FTDisplayRateMonitor;
@protocol FTUIViewControllerHandler <NSObject>
-(void)notify_viewDidAppear:(UIViewController *)viewController animated:(BOOL)animated;
-(void)notify_viewDidDisappear:(UIViewController *)viewController animated:(BOOL)animated;
@end

@protocol FTUIEventHandler <NSObject>
-(void)notify_sendAction:(UIView *)view;
-(void)notify_sendActionWithPressType:(UIPressType)type view:(UIView *)view;
@end
/// View and Action collection class
@interface FTAutoTrackHandler : NSObject

/// Handle ViewController lifecycle rum: startView, stopView
@property (nonatomic, weak) id<FTUIViewControllerHandler> viewControllerHandler;

@property (nonatomic, weak) id<FTUIEventHandler> actionHandler;

@property (nonatomic, weak, readonly) id<FTRumDatasProtocol> addRumDatasDelegate;
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
            actionHandler:(nullable FTActionTrackingHandler)actionHandler
           displayMonitor:(nullable FTDisplayRateMonitor *)displayMonitor;

-(void)shutDown;
@end

NS_ASSUME_NONNULL_END
