//
//  ZYViewController_log.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYViewController_log.h"
#import "UIView+ZY_currentController.h"
#import "UIViewController+ZY_RootVC.h"
#import "ZYAspects.h"
#import <UIKit/UIKit.h>
#import "ZYLog.h"
#import "ZYTrackerEventDBTool.h"
#import "RecordModel.h"
#import "ZYBaseInfoHander.h"
#import <objc/runtime.h>
@interface ZYViewController_log()
@property (nonatomic, strong) NSDate *lastSentDate;

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
       [UIViewController aspect_hookSelector:@selector(loadView) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
            UIViewController * vc = [info instance];
                   NSDictionary *data = @{@"cpn":NSStringFromClass([vc class]),
                                          @"rpn":[UIViewController zy_getRootViewController],
                                          @"op":@"open",
                   };
                [self addDBWithData:data];
                   ZYDebug(@"data == %@",data);
         } error:nil];
     
       SEL sel= NSSelectorFromString(@"dealloc");
       [UIViewController aspect_hookSelector:sel withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
           UIViewController *tempVC = (UIViewController *)info.instance;
           NSDictionary *data =@{@"cpn":NSStringFromClass([tempVC class]),
                                 @"rpn":[UIViewController zy_getRootViewController],
                                 @"op":@"close",
               };
              [self addDBWithData:data];
            ZYDebug(@"data == %@",data);

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
             NSDictionary *data =@{@"cpn":className,
                                   @"rpn":[UIViewController zy_getRootViewController],
                                   @"op":@"click",
                                   @"opdata":@{@"vtp":[tableView getParentsView]},
                           };
            [self addDBWithData:data];
             ZYDebug(@"data == %@",data);
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
             NSDictionary *data =@{@"cpn":className,
                                   @"rpn":[UIViewController zy_getRootViewController],
                                   @"op":@"click",
                                   @"opdata":@{@"vtp":[collectionView getParentsView]},
                                  };
             [self addDBWithData:data];
             ZYDebug(@"data == %@",data);

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
               NSDictionary *data =@{@"cpn":className,
                                     @"rpn":[UIViewController zy_getRootViewController],
                                     @"op":@"click",
                                     @"opdata":@{@"vtp":[button getParentsView]},
                                     };
                [self addDBWithData:data];
                ZYDebug(@"data == %@",data);
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
                    NSDictionary *data =@{@"cpn":NSStringFromClass([target class]),
                                          @"rpn":[UIViewController zy_getRootViewController],
                                          @"op":@"click",
                                          @"opdata":@{@"vtp":[ges.view getParentsView]},
                                                        };
                    [self addDBWithData:data];
                     ZYDebug(@"data == %@",data);

                } error:nil];
            }
            
        }
       } error:NULL];
   
      [UITouch aspect_hookSelector:@selector(touchesForGestureRecognizer:)
              withOptions:ZY_AspectPositionAfter
               usingBlock:^(id<ZY_AspectInfo> aspectInfo, UIGestureRecognizer *gesture) {
               UIView *gesView = gesture.view;
               NSString *selName = gesture.accessibilityHint;
               ZYDebug(@"当前控制器：%@ 按钮方法：%@  name = %@",[[gesView getCurrentViewController] class],selName,gesture.name);

               } error:NULL];
      
}

-(void)addDBWithData:(NSDictionary *)data{
    if (self.lastSentDate) {
        NSDate* now = [NSDate date];
        NSTimeInterval time = [now timeIntervalSinceDate:self.lastSentDate];
        if (time>10) {
            if (self.block) {
                self.block();
            }
        }
    }else{
        self.lastSentDate = [NSDate date];
    }
      RecordModel *model = [RecordModel new];
      model.tm = [ZYBaseInfoHander getCurrentTimestamp];
      model.data =[ZYBaseInfoHander convertToJsonData:data];
      [[ZYTrackerEventDBTool sharedManger] insertItemWithItemData:model];
}
@end
