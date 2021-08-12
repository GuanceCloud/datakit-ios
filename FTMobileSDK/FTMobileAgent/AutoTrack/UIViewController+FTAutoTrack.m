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
#import "BlacklistedVCClassNames.h"
#import "FTLog.h"
#import "FTMonitorManager.h"
#import "FTDateUtil.h"
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
-(NSString *)ft_viewControllerId{
    return [self.ft_viewControllerName ft_md5HashToUpper32Bit];
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
- (BOOL)isBlackListContainsViewController{
    static NSSet * blacklistedClasses  = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            NSArray *blacklistedViewControllerClassNames =[BlacklistedVCClassNames ft_blacklistedViewControllerClassNames];
            blacklistedClasses = [NSSet setWithArray:blacklistedViewControllerClassNames];
            
        } @catch(NSException *exception) {  // json加载和解析可能失败
            ZYDebug(@"error: %@",exception);
        }
    });
    
    __block BOOL isContains = NO;
    [blacklistedClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *blackClassName = (NSString *)obj;
        Class blackClass = NSClassFromString(blackClassName);
        if (blackClass && [self isKindOfClass:blackClass]) {
            isContains = YES;
            *stop = YES;
        }
    }];
    return isContains;
}

- (void)dataflux_viewDidLoad{
    self.ft_viewLoadStartTime =[NSDate date];
    [self dataflux_viewDidLoad];
}
-(void)dataflux_viewDidAppear:(BOOL)animated{
    [self dataflux_viewDidAppear:animated];
    if(![self isBlackListContainsViewController]){
        // 预防撤回侧滑
        if ([FTMonitorManager sharedInstance].currentController != self) {
            if(self.ft_viewLoadStartTime){
                NSNumber *loadTime = [FTDateUtil nanotimeIntervalSinceDate:[NSDate date] toDate:self.ft_viewLoadStartTime];
                self.ft_loadDuration = loadTime;
                self.ft_viewLoadStartTime = nil;
            }else{
                NSNumber *loadTime = @0;
                self.ft_loadDuration = loadTime;
            }
            self.ft_viewUUID = [NSUUID UUID].UUIDString;
            [[FTMonitorManager sharedInstance] trackViewDidAppear:self];
        }
      
    }
}
-(void)dataflux_viewDidDisappear:(BOOL)animated{
    [self dataflux_viewDidDisappear:animated];
    if([self isBlackListContainsViewController]){
        return;
    }
    if ([FTMonitorManager sharedInstance].currentController == self) {
        [[FTMonitorManager sharedInstance] trackViewDidDisappear:self];
    }
}
@end
