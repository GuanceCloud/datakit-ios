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
static char *viewLoadStartTimeKey = "viewLoadStartTimeKey";
static char *viewControllerUUID = "viewControllerUUID";
static char *viewLoadDuration = "viewLoadDuration";

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
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:self animated:animated];
}
-(void)ft_viewDidDisappear:(BOOL)animated{
    [self ft_viewDidDisappear:animated];
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidDisappear:self animated:animated];
}

-(BOOL)ft_parentViewControllerIsContainer{
    UIViewController *parent = self.parentViewController;
    while (parent != nil) {
        if ([parent isKindOfClass:UIPageViewController.class] || [parent isKindOfClass:UISplitViewController.class]) {
            return YES;
        }else{
            parent = parent.parentViewController;
        }
    }
    return NO;
}
@end
