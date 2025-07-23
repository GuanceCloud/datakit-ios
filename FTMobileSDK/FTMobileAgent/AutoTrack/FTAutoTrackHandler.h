//
//  FTTrack.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/11/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTRumDatasProtocol.h"
#import "FTAutoTrackProperty.h"
#import "FTRumConfig.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTUIViewControllerHandler <NSObject>
-(void)notify_viewDidAppear:(UIViewController *)viewController animated:(BOOL)animated;
-(void)notify_viewDidDisappear:(UIViewController *)viewController animated:(BOOL)animated;
@end
/// View、Action 采集类
@interface FTAutoTrackHandler : NSObject<FTUIViewControllerHandler>
/// 传递事件对象，将采集到的 view、action 数据传递给 RUM
@property (nonatomic, weak) id<FTRumDatasProtocol> addRumDatasDelegate;
/// 处理 ViewController 生命周期 rum:startView、stopView
@property (nonatomic, weak) id<FTUIViewControllerHandler> viewControllerHandler;
/// A handler for user-defined collection of `UIViewControllers` as RUM views for tracking
@property (nonatomic, copy, nullable) FTUIKitViewsHandler uiKitViewsHandler;

/// 单例
+ (instancetype)sharedInstance;

/// 开启采集
/// - Parameters:
///   - enable: 是否采集 View 数据
///   - enable: 是否采集 Action 数据
-(void)startWithTrackView:(BOOL)enable action:(BOOL)enable;

-(void)shutDown;
@end

NS_ASSUME_NONNULL_END
