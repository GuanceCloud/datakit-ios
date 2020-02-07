//
//  ZYViewController_log.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTAutoTrack.h"
#import "UIView+ZY_currentController.h"
#import "UIViewController+ZY_RootVC.h"
#import "ZYAspects.h"
#import <UIKit/UIKit.h>
#import "ZYLog.h"
#import "ZYTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "ZYBaseInfoHander.h"
#import <objc/runtime.h>
#import "FTMobileConfig.h"
#import "FTMobileAgent.h"
#import "FTUncaughtExceptionHandler.h"
NSString * const FT_AUTO_TRACK_OP_OPEN  = @"open";
NSString * const FT_AUTO_TRACK_OP_CLOSE  = @"close";
NSString * const FT_AUTO_TRACK_OP_CLICK  = @"click";
NSString * const FT_AUTO_TRACK_OP_LAUNCH  = @"launch";

@interface FTAutoTrack()
@property (nonatomic, strong) FTMobileConfig *config;

@end
@implementation FTAutoTrack

-(void)startWithConfig:(FTMobileConfig *)config{
    self.config = config;
    [self setLogContent];
}
-(void)setLogContent{
    if (!self.config.enableAutoTrack || self.config.autoTrackEventType &  FTAutoTrackTypeNone) {
        return;
    }
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    if (self.config.autoTrackEventType & FTAutoTrackEventTypeAppStart) {
        [notificationCenter addObserver:self
                                     selector:@selector(appDidFinishLaunchingWithOptions:)
                                            name:UIApplicationDidFinishLaunchingNotification
                                          object:nil];
    }
  
    if (self.config.autoTrackEventType & FTAutoTrackEventTypeAppClick) {
        [self logTableViewCollectionView];
        [self logTargetAction];
    }
    if (self.config.autoTrackEventType & FTAutoTrackEventTypeAppViewScreen) {
        [self logViewControllerLifeCycle];
    }
    if (self.config.enableTrackAppCrash) {
        [FTUncaughtExceptionHandler installUncaughtExceptionHandler];
    }
  
}
- (void)appDidFinishLaunchingWithOptions:(NSNotification *)notification{
    
    [self track:FT_AUTO_TRACK_OP_LAUNCH withCpn:nil WithClickView:nil];
    
}
- (void)appWillTerminateNotification:(NSNotification *)notification{
       
}
#pragma mark ========== 控制器的生命周期 ==========
- (void)logViewControllerLifeCycle{
       [UIViewController aspect_hookSelector:@selector(loadView) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
            UIViewController * vc = [info instance];

           [self track:FT_AUTO_TRACK_OP_OPEN withCpn:vc WithClickView:nil];
           
         } error:nil];
     
       SEL sel= NSSelectorFromString(@"dealloc");
       [UIViewController aspect_hookSelector:sel withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
           UIViewController *tempVC = (UIViewController *)info.instance;

           [self track:FT_AUTO_TRACK_OP_CLOSE withCpn:tempVC WithClickView:nil];
       } error:nil];
    
}
#pragma mark ========== UITableView\UICollectionView的点击事件 ==========
- (void)logTableViewCollectionView{

        [UITableView aspect_hookSelector:@selector(setDelegate:)
                  withOptions:ZY_AspectPositionAfter
                                  usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {

                Class vcClass = [target class];
                [vcClass aspect_hookSelector:@selector(tableView:didSelectRowAtIndexPath:)
                 withOptions:ZY_AspectPositionBefore
                  usingBlock:^(id<ZY_AspectInfo> aspectInfo, UITableView *tableView, NSIndexPath *indexPath) {
                    [self track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:tableView];
                } error:NULL];
                
            }error:nil];
           

     [UICollectionView aspect_hookSelector:@selector(setDelegate:)
           withOptions:ZY_AspectPositionAfter
                           usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {

         Class vcClass = [target class];
         [vcClass aspect_hookSelector:@selector(collectionView:didSelectItemAtIndexPath:)
          withOptions:ZY_AspectPositionBefore
           usingBlock:^(id<ZY_AspectInfo> aspectInfo, UICollectionView *collectionView, NSIndexPath *indexPath) {
             [self track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:collectionView];
         } error:NULL];
         
     }error:nil];
   

}

#pragma mark ========== button,Gesture的点击事件 ==========
- (void)logTargetAction{
    //待处理：仅可以实现
    [UIGestureRecognizer aspect_hookSelector:@selector(addTarget:action:)
      withOptions:ZY_AspectPositionAfter
       usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action) {
        if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]]) {
            UIGestureRecognizer *ges = aspectInfo.instance;

            ges.accessibilityHint = NSStringFromSelector(action);

            if ([target isKindOfClass:[UIViewController class]]) {
                Class vcClass = [target class];
                [vcClass aspect_hookSelector:action withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                [self track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:ges.view];

                } error:nil];
            }
            
        }
       } error:NULL];

       [UIGestureRecognizer aspect_hookSelector:@selector(initWithTarget:action:)
            withOptions:ZY_AspectPositionAfter
             usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action) {
              if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]]) {
                  UIGestureRecognizer *ges = aspectInfo.instance;

                  ges.accessibilityHint = NSStringFromSelector(action);

                  if ([target isKindOfClass:[UIViewController class]]) {
                     Class vcClass = [target class];
                      
                     [vcClass aspect_hookSelector:action withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                      [self track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:ges.view];

                      } error:nil];
                  }
                  
              }
             } error:NULL];
       
    [UIApplication aspect_hookSelector:@selector(sendAction:to:from:forEvent:) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo, SEL action,id to,id  from,UIEvent *event) {
        if (![from isKindOfClass:UIView.class]) {
            return ;
        }
             NSString *className = NSStringFromClass([to class]);
            UIViewController *vc;
            if (![to isKindOfClass:UIViewController.class]) {
                vc = [to zy_getCurrentViewController];
                className = NSStringFromClass([vc class]);
            }else{
                vc = to;
            }
            [self track:FT_AUTO_TRACK_OP_CLICK withCpn:to WithClickView:from];
          } error:NULL];
}
- (BOOL)isAutoTrackUI:(Class )view{

    if (self.config.whiteViewClass.count>0) {
      return  [self isViewTypeWhite:view];
    }
    if(self.config.blackViewClass.count>0)   return ![self isViewTypeIgnored:view];
  
    return YES;
}
- (BOOL)isViewTypeWhite:(Class)aClass {
    for (Class obj in self.config.whiteViewClass) {
        if ([aClass isSubclassOfClass:obj]) {
            return YES;
        }
    }
    return NO;
}
- (BOOL)isViewTypeIgnored:(Class)aClass {
    for (Class obj in self.config.blackViewClass) {
        if ([aClass isSubclassOfClass:obj]) {
            return YES;
        }
    }
    return NO;
}
- (BOOL)judgeWhiteAndBlackWithViewController:(UIViewController *)viewController{
    //没有设置白名单  就考虑黑名单
    if (self.config.whiteVCList.count == 0) {
        return ![self isBlackListContainsViewController:viewController];
    }
    
    return [self isWhiteListContainsViewController:viewController];
}
- (BOOL)isWhiteListContainsViewController:(UIViewController *)viewController{
    NSSet *whitelistedClasses = [NSSet setWithArray:self.config.whiteVCList];
    __block BOOL isContains = NO;
     [whitelistedClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
         NSString *whiteClassName = (NSString *)obj;
         Class whiteClass = NSClassFromString(whiteClassName);
         if (whiteClass && [viewController isKindOfClass:whiteClass]) {
             isContains = YES;
             *stop = YES;
         }
     }];
    if (isContains) {
        return YES;
    }
    
    return isContains;
    
}
- (BOOL)isBlackListContainsViewController:(UIViewController *)viewController {
    static NSSet *blacklistedClasses = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
       NSString *strPath = [[NSBundle mainBundle] pathForResource:@"FTAutoTrack" ofType:@"framework"];
       NSString *bundlePath = [[NSBundle bundleWithPath:strPath] pathForResource:@"FTAutoTrack" ofType:@"bundle"];
       NSString *jsonPath = [[NSBundle bundleWithPath:bundlePath] pathForResource:@"ft_autotrack_viewcontroller_blacklist" ofType:@"json"];
       NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
        @try {
            NSMutableArray *array = [[NSMutableArray alloc]initWithArray:self.config.blackVCList];
            NSArray *blacklistedViewControllerClassNames = [NSJSONSerialization JSONObjectWithData:jsonData  options:NSJSONReadingAllowFragments  error:nil];
            [array addObjectsFromArray:blacklistedViewControllerClassNames];
            blacklistedClasses = [NSSet setWithArray:array];
        } @catch(NSException *exception) {  // json加载和解析可能失败
            ZYDebug(@"error: %@",exception);
        }
    });
    __block BOOL isContains = NO;
    [blacklistedClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *blackClassName = (NSString *)obj;
        Class blackClass = NSClassFromString(blackClassName);
        if (blackClass && [viewController isKindOfClass:blackClass]) {
            isContains = YES;
            *stop = YES;
        }
    }];
    return isContains;
}
#pragma mark ========== 写入数据库操作 ==========
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view{
    if (![self judgeWhiteAndBlackWithViewController:cpn]) {
        return ;
    }
    if (view != nil && ![self isAutoTrackUI:[view class]]) {
        return ;
    }
    @try {
        NSMutableDictionary *tags = [NSMutableDictionary new];
        NSDictionary *value = @{@"event":op};
        NSString *field = @"mobile_tracker";
        if (![op isEqualToString:FT_AUTO_TRACK_OP_LAUNCH]) {
            [tags addEntriesFromDictionary:@{@"rpn":[UIViewController zy_getRootViewController]}];
            if ([cpn isKindOfClass:UIView.class]) {
              [tags addEntriesFromDictionary:@{@"cpn":NSStringFromClass([cpn zy_getCurrentViewController].class)}];
            }else if ([cpn isKindOfClass:UIViewController.class]){
              [tags addEntriesFromDictionary:@{@"cpn":NSStringFromClass([cpn class])}];
            }
            if ([op isEqualToString:FT_AUTO_TRACK_OP_CLICK]&&[view isKindOfClass:UIView.class]) {
                [tags addEntriesFromDictionary:@{@"vtp":[view zy_getParentsView]}];
            }
        }
        [[FTMobileAgent sharedInstance] track:field tags:tags values:value];
       
    } @catch (NSException *exception) {
        ZYDebug(@" error: %@", exception);
    }
}
@end
