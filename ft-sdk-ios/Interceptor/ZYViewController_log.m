//
//  ZYViewController_log.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYViewController_log.h"
#import "UIView+ZY_currentController.h"
#import "ZYAspects.h"
#import <UIKit/UIKit.h>
#import "ZYLog.h"
#import "ZYTrackerEventDBTool.h"

@interface ZYViewController_log()


@end
@implementation ZYViewController_log

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setLogContent];
    }
    return self;
}
-(void)setLogContent{
    [self logViewControllerLifeCycle];
    [self logTableViewCollectionView];
    [self logTargetAction];
}

#pragma mark ========== 控制器的生命周期 ==========
- (void)logViewControllerLifeCycle{
    [UIViewController aspect_hookSelector:@selector(viewWillAppear:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
           UIViewController * vc = [info instance];
            ZYDebug(@"%@ viewWillAppear",[vc class]);
       } error:nil];
       [UIViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
             UIViewController *tempVC = (UIViewController *)info.instance;
            ZYDebug(@"%@ viewDidLoad",[tempVC class]);
         } error:nil];
       [UIViewController aspect_hookSelector:@selector(viewDidDisappear:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
                UIViewController *tempVC = (UIViewController *)info.instance;
            ZYDebug(@"%@ viewDidDisappear",[tempVC class]);
       } error:nil];
    
}
#pragma mark ========== UITableView\UICollectionView的点击事件 ==========
- (void)logTableViewCollectionView{
    // UITableView、UICollectionView 先找到设置代理的实例对象 再进行hook处理 
     [UITableView aspect_hookSelector:@selector(setDelegate:)
       withOptions:ZY_AspectPositionAfter
        usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
         [target aspect_hookSelector:@selector(tableView:didSelectRowAtIndexPath:)
               withOptions:ZY_AspectPositionBefore
                usingBlock:^(id<ZY_AspectInfo> aspectInfo,UITableView *tableView, NSIndexPath *indexPath) {
             NSString *className;
             if ([aspectInfo.instance isKindOfClass:[UIViewController class]]) {
                 className  =NSStringFromClass([aspectInfo.instance class]);
             }else if([aspectInfo.instance isKindOfClass:[UIView class]]){
                 className  =NSStringFromClass([[aspectInfo.instance getCurrentViewController] class]);
             }
                ZYDebug(@"\n当前控制器：%@ \n方法tableView:didSelectRowAtIndexPath：%@ ",className,indexPath);
              } error:NULL];
         
            
      } error:NULL];
     [UICollectionView aspect_hookSelector:@selector(setDelegate:)
           withOptions:ZY_AspectPositionAfter
                           usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
         [target aspect_hookSelector:@selector(collectionView:didSelectItemAtIndexPath:)
          withOptions:ZY_AspectPositionAfter
           usingBlock:^(id<ZY_AspectInfo> aspectInfo, UICollectionView *collectionView, NSIndexPath *indexPath) {
                NSString *className;
                if ([aspectInfo.instance isKindOfClass:[UIViewController class]]) {
                    className  =NSStringFromClass([aspectInfo.instance class]);
                }else if([aspectInfo.instance isKindOfClass:[UIView class]]){
                    className  =NSStringFromClass([[aspectInfo.instance getCurrentViewController] class]);
                }
            ZYDebug(@"当前控制器：%@ collectionView:didSelectItemAtIndexPath：%@ ",className,indexPath);
         } error:NULL];
         
     }error:nil];
    
}
#pragma mark ========== button,Gesture的点击事件 ==========
- (void)logTargetAction{
    [UIButton aspect_hookSelector:@selector(addTarget:action:forControlEvents:)
         withOptions:ZY_AspectPositionAfter
          usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action, UIControlEvents controlEvents) {

              if ([aspectInfo.instance isKindOfClass:[UIButton class]]) {

                  UIButton *button = aspectInfo.instance;
                  button.accessibilityHint = NSStringFromSelector(action);
              }
          } error:NULL];
      [UIControl aspect_hookSelector:@selector(beginTrackingWithTouch:withEvent:)
      withOptions:ZY_AspectPositionAfter
       usingBlock:^(id<ZY_AspectInfo> aspectInfo, UITouch *touch, UIEvent *event) {

           if ([aspectInfo.instance isKindOfClass:[UIButton class]]) {

               UIButton *button = aspectInfo.instance;
               id object =  [button.allTargets anyObject];
               NSString *className = NSStringFromClass([object class]);
               ZYDebug(@"当前控制器：%@ 按钮方法：%@ aspectInfo%@",className,button.accessibilityHint,button);
           }
       } error:NULL];
    //待处理：仅可以实现
    [UIGestureRecognizer aspect_hookSelector:@selector(addTarget:action:)
      withOptions:ZY_AspectPositionAfter
       usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action) {
        if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]]) {
            UIGestureRecognizer *ges = aspectInfo.instance;
            ges.accessibilityHint = NSStringFromSelector(action);
            
            if ([target isKindOfClass:[UIViewController class]]) {
                [target aspect_hookSelector:action withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                   ZYDebug(@"当前控制器：%@UIGestureRecognizer ：%@ selector name",[target class],NSStringFromSelector(action));
                } error:nil];
            }
            
        }
       } error:NULL];
   
      [UIEvent aspect_hookSelector:@selector(touchesForGestureRecognizer:)
              withOptions:ZY_AspectPositionAfter
               usingBlock:^(id<ZY_AspectInfo> aspectInfo, UIGestureRecognizer *gesture) {
               UIView *gesView = gesture.view;
               NSString *selName = gesture.accessibilityHint;
               ZYDebug(@"当前控制器：%@ 按钮方法：%@  name = %@",[[gesView getCurrentViewController] class],selName,gesture.name);

               } error:NULL];
      
}

@end
