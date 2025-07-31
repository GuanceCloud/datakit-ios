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
#import "FTViewTrackingStrategy.h"
#import "FTActionTrackingStrategy.h"
NS_ASSUME_NONNULL_BEGIN
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
/// Pass event object, pass collected view and action data to RUM
@property (nonatomic, weak) id<FTRumDatasProtocol> addRumDatasDelegate;
/// Handle ViewController lifecycle rum: startView, stopView
@property (nonatomic, weak) id<FTUIViewControllerHandler> viewControllerHandler;

@property (nonatomic, weak) id<FTUIEventHandler> actionHandler;

/// A strategy for user-defined collection of `ViewControllers` as RUM views for tracking
@property (nonatomic, weak) FTViewTrackingStrategy uiKitViewTrackingStrategy;

@property (nonatomic, weak) FTActionTrackingStrategy actionTrackingStrategy;


/// Singleton
+ (instancetype)sharedInstance;

/// Enable collection
/// - Parameters:
///   - enable: Whether to collect View data
///   - enable: Whether to collect Action data
-(void)startWithTrackView:(BOOL)enable action:(BOOL)enable;

-(void)shutDown;
@end

NS_ASSUME_NONNULL_END
