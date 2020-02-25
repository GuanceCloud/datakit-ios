//
//  UIViewController+FlowChart.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/2/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import "UIViewController+FlowChart.h"
#import <objc/runtime.h>



@implementation UIViewController (FlowChart)
+ (void)load {
    Method originalSelector = class_getInstanceMethod(self, @selector(viewDidAppear:));
    Method swizzledSelector = class_getInstanceMethod(self, @selector(ft_swizzle_viewDidAppear:));
    method_exchangeImplementations(originalSelector, swizzledSelector);
}

- (void)ft_swizzle_viewDidAppear:(BOOL)animated
{
    //在这里填写需要插入的代码
    [self trackFlowChartData];

    //执行原来的代码，不影响代码逻辑
    [self ft_swizzle_viewDidAppear:animated];
}

- (void)trackFlowChartData {
    @try {
        
   
    if ([self isKindOfClass:UITabBarController.class] ||[self isKindOfClass:UINavigationController.class]) {
        return;
    }
    if ([self.presentingViewController isKindOfClass:NSNull.class] || [self.parentViewController isKindOfClass:UITabBarController.class]||[self.parentViewController isKindOfClass:UINavigationController.class]) {
        NSLog(@"null = %d UITabBarController = %d UINavigationController = %d",[self.parentViewController isKindOfClass:NSNull.class],[self.parentViewController isKindOfClass:UITabBarController.class],[self.parentViewController isKindOfClass:UINavigationController.class]);
        NSLog(@"name:%@ self.parentViewController:%@",NSStringFromClass(self.class),self.parentViewController);

       
    }
    
        } @catch (NSException *exception) {
               
        }

}
@end
