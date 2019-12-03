//
//  UIViewController+ZYRootVC.m
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UIViewController+ZY_RootVC.h"

@implementation UIViewController (ZY_RootVC)
+ (UIViewController *)zy_getRootViewController{

    UIWindow* window = [[[UIApplication sharedApplication] delegate] window];
    NSAssert(window, @"The window is empty");
    return window.rootViewController;
}
@end
