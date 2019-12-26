//
//  UIView+ZY_currentController.h
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/29.
//  Copyright © 2019 hll. All rights reserved.
//



#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (ZY_currentController)
-(UIViewController *)zy_getCurrentViewController;
-(NSString *)zy_getParentsView;
@end

NS_ASSUME_NONNULL_END
