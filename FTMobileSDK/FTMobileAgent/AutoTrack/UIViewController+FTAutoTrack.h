//
//  UIViewController+FT_RootVC.h
//  FTAutoTrack
//
//  Created by hulilei on 2019/12/2.
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

/// The last page, prevent duplicate collection of View events from side sliding/sliding
@property (nonatomic, strong,nullable) UIViewController *ft_previousViewController;

@end
NS_ASSUME_NONNULL_END
