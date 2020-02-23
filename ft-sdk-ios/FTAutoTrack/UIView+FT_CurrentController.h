//
//  UIView+ZY_currentController.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//



#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (FT_CurrentController)
-(UIViewController *)ft_getCurrentViewController;
-(NSString *)ft_getParentsView;
@end

NS_ASSUME_NONNULL_END
