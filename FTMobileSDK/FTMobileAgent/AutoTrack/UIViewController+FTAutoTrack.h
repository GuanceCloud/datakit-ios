//
//  UIViewController+FT_RootVC.h
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FTAutoTrackProperty.h"
NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (FTAutoTrack)<FTRumViewProperty>
-(BOOL)isBlackListContainsViewController;
- (BOOL)isActionBlackListContainsViewController;
-(NSString *)ft_viewControllerName;
-(void)ft_viewDidLoad;
-(void)ft_viewDidAppear:(BOOL)animated;
-(void)ft_viewDidDisappear:(BOOL)animated;
@end

@interface UINavigationController (FTAutoTrack)

/// 上一次页面，防止侧滑/下滑重复采集 View 事件
@property (nonatomic, strong,nullable) UIViewController *ft_previousViewController;

@end
NS_ASSUME_NONNULL_END
