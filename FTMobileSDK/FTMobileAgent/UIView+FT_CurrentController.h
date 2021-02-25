//
//  UIView+FT_CurrentController.h
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//



#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (FT_CurrentController)
/**
 *  获取当前控制器
*/
-(UIViewController *)ft_currentViewController;
/**
 *  获取当前控件的视图树
*/
-(NSString *)ft_parentsView;
@end

NS_ASSUME_NONNULL_END
