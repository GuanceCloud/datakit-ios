//
//  UIViewController+FT_RootVC.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "UIViewController+FTAutoTrack.h"
#import <objc/runtime.h>
#import "FTConstants.h"
#import "FTBaseInfoHander.h"
#import "NSString+FTAdd.h"
static char *viewLoadStartTimeKey = "viewLoadStartTimeKey";
static char *viewControllerUUID = "viewControllerUUID";

@implementation UIViewController (FTAutoTrack)
-(void)setFt_viewLoadStartTime:(NSDate*)viewLoadStartTime{
    objc_setAssociatedObject(self, &viewLoadStartTimeKey, viewLoadStartTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSDate *)ft_viewLoadStartTime{
    return objc_getAssociatedObject(self, &viewLoadStartTimeKey);
}
- (NSString *)ft_viewControllerName{
    return NSStringFromClass([self class]);
}
-(NSString *)ft_viewUUID{
    return objc_getAssociatedObject(self, &viewControllerUUID);
}
-(void)setFt_viewUUID:(NSString *)ft_viewUUID{
    objc_setAssociatedObject(self, &viewControllerUUID, ft_viewUUID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
+ (NSString *)ft_getRootViewController{
    __block NSString *name;
    [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
     UIWindow* window =[FTBaseInfoHander keyWindow];
    name = NSStringFromClass([window.rootViewController class]);
    }];
    if( [name isKindOfClass:NSNull.class]
       ||name==nil){
        return FT_NULL_VALUE;
    }else{
        return  name;
    }
}
-(NSString *)ft_parentVC{
    UIViewController *viewController =[self parentViewController];
    if (viewController == nil) {
        viewController = self.presentingViewController;
    }
    if (viewController == nil) {
        return FT_NULL_VALUE;
    }
    return NSStringFromClass(viewController.class);
}
-(NSString *)ft_VCPath{
    UIViewController *viewController =self;
    NSMutableString *viewPaths = [NSMutableString new];
    [viewPaths insertString:[FTBaseInfoHander itemHeatMapPathForResponder:viewController] atIndex:0];
    viewController = (UIViewController *)viewController.parentViewController;
    while (viewController){
        [viewPaths insertString:[NSString stringWithFormat:@"%@/",[FTBaseInfoHander itemHeatMapPathForResponder:viewController]] atIndex:0];
        viewController = (UIViewController *)viewController.parentViewController;
    }
   return viewPaths;
}
@end
