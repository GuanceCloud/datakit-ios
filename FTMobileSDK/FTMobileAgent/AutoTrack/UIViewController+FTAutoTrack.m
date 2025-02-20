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
#import "BlacklistedVCClassNames.h"
#import "FTLog+Private.h"
#import "FTAutoTrackHandler.h"
#import "NSDate+FTUtil.h"
#import "FTBaseInfoHandler.h"
#import "FTWeakPropertyContainer.h"

static char *viewLoadStartTimeKey = "viewLoadStartTimeKey";
static char *viewControllerUUID = "viewControllerUUID";
static char *viewLoadDuration = "viewLoadDuration";
static char *previousViewController = "previousViewController";

@implementation UIViewController (FTAutoTrack)
-(void)setFt_viewLoadStartTime:(NSDate*)viewLoadStartTime{
    objc_setAssociatedObject(self, &viewLoadStartTimeKey, viewLoadStartTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSDate *)ft_viewLoadStartTime{
    return objc_getAssociatedObject(self, &viewLoadStartTimeKey);
}
-(NSNumber *)ft_loadDuration{
    return objc_getAssociatedObject(self, &viewLoadDuration);
}
-(void)setFt_loadDuration:(NSNumber *)ft_loadDuration{
    objc_setAssociatedObject(self, &viewLoadDuration, ft_loadDuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
- (BOOL)isActionBlackListContainsViewController{
    @try {
        NSDictionary *black = [BlacklistedVCClassNames ft_blacklistedViewControllerClassNames];
        NSDictionary *blackList = black[FT_BLACK_LIST_VIEW_ACTION];
        if(blackList && blackList.count>0){
            for (NSString *publicClass in blackList[@"public"]) {
                if ([self isKindOfClass:NSClassFromString(publicClass)]) {
                    return YES;
                }
            }
        }
        return [(NSArray *)blackList[@"private"] containsObject:NSStringFromClass(self.class)];
    } @catch(NSException *exception) {
        FTInnerLogError(@"error: %@",exception);
    }
}
- (BOOL)isBlackListContainsViewController{
    @try {
        NSDictionary *black = [BlacklistedVCClassNames ft_blacklistedViewControllerClassNames];
        NSDictionary *blackList = black[FT_BLACK_LIST_VIEW];
        if(blackList && blackList.count>0){
            for (NSString *publicClass in blackList[@"public"]) {
                if ([self isKindOfClass:NSClassFromString(publicClass)]) {
                    return YES;
                }
            }
        }
        return [(NSArray *)blackList[@"private"] containsObject:NSStringFromClass(self.class)];
    } @catch(NSException *exception) {
        FTInnerLogError(@"error: %@",exception);
    }
}
- (void)ft_viewDidLoad{
    self.ft_viewLoadStartTime = [NSDate date];
    [self ft_viewDidLoad];
}
-(void)ft_viewDidAppear:(BOOL)animated{
    [self ft_viewDidAppear:animated];
    // 防止 tabbar 切换，可能漏采 startView 全埋点
    if ([self isKindOfClass:UINavigationController.class]) {
        UINavigationController *nav = (UINavigationController *)self;
        nav.ft_previousViewController = nil;
    }
    if (self.navigationController && self.parentViewController == self.navigationController) {
        // 忽略由于侧滑部分返回原页面，重复触发 startView 事件
        if (self.navigationController.ft_previousViewController == self) {
            return;
        }
    }
    if (!self.parentViewController ||
        [self.parentViewController isKindOfClass:[UITabBarController class]] ||
        [self.parentViewController isKindOfClass:[UINavigationController class]] ||
        [self.parentViewController isKindOfClass:[UIPageViewController class]] ||
        [self.parentViewController isKindOfClass:[UISplitViewController class]]) {
        [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:self animated:animated];
    }
    // 标记 previousViewController
    if (self.navigationController && self.parentViewController == self.navigationController) {
        self.navigationController.ft_previousViewController = self;
    }
}
-(void)ft_viewDidDisappear:(BOOL)animated{
    [self ft_viewDidDisappear:animated];
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidDisappear:self animated:animated];
}
@end
@implementation UINavigationController (FTAutoTrack)

- (void)setFt_previousViewController:(UIViewController *)ft_previousViewController {
    FTWeakPropertyContainer *container = [FTWeakPropertyContainer containerWithWeakProperty:ft_previousViewController];
    objc_setAssociatedObject(self, previousViewController, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIViewController *)ft_previousViewController {
    FTWeakPropertyContainer *container = objc_getAssociatedObject(self, previousViewController);
    return container.weakProperty;
}

@end
