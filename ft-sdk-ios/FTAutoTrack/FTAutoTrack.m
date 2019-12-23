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
#import "RecordModel.h"
#import "ZYBaseInfoHander.h"
#import <objc/runtime.h>
#import "FTMobileConfig.h"
@interface FTAutoTrack()
@property (nonatomic, strong) NSDate *lastSentDate;
@property (nonatomic, strong) FTMobileConfig *config;

@end
@implementation FTAutoTrack

-(void)startWithConfig:(FTMobileConfig *)config{
    self.config = config;
    [self setLogContent];
}
-(void)setLogContent{
    if (!self.config.enableAutoTrack) {
        return;
    }
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    if (self.config.autoTrackEventType == FTAutoTrackEventTypeAppStart) {
        [notificationCenter addObserver:self
                                     selector:@selector(appDidFinishLaunchingWithOptions:)
                                            name:UIApplicationDidFinishLaunchingNotification
                                          object:nil];
    }
    if (self.config.autoTrackEventType == FTAutoTrackEventTypeAppEnd) {
        [notificationCenter addObserver:self
        selector:@selector(appWillTerminateNotification:)
               name:UIApplicationWillTerminateNotification
             object:nil];
    }
    if (self.config.autoTrackEventType == FTAutoTrackEventTypeAppClick) {
        [self logTableViewCollectionView];
        [self logTargetAction];
    }
    if (self.config.autoTrackEventType == FTAutoTrackEventTypeAppViewScreen) {
        [self logViewControllerLifeCycle];
    }
}
- (void)appDidFinishLaunchingWithOptions:(NSNotification *)notification{
        NSDictionary *data =@{
                            @"op":@"launch",
                            };
        [self addDBWithData:data];
}
- (void)appWillTerminateNotification:(NSNotification *)notification{
       
}
#pragma mark ========== 控制器的生命周期 ==========
- (void)logViewControllerLifeCycle{
       [UIViewController aspect_hookSelector:@selector(loadView) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
            UIViewController * vc = [info instance];
           if ([self isBlackListContainsViewController:vc]) {
               return ;
           }
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
           if ([self isBlackListContainsViewController:tempVC]) {
               return ;
           }
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
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
     [notificationCenter addObserver:self
                                  selector:@selector(tableViewSelectionDidChangeNotification:)
                                         name:UITableViewSelectionDidChangeNotification
                                       object:nil];
    
}
- (void)tableViewSelectionDidChangeNotification:(NSNotification *)notification{
    ZYDebug(@"tableViewSelectionDidChangeNotification == %@",notification);
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
               if ([self isBlackListContainsViewController:object]) {
                             return ;
                }
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
   
     
      
}
- (BOOL)isBlackListContainsViewController:(UIViewController *)viewController {
    static NSSet *blacklistedClasses = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
       
        NSBundle *sensorsBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[FTAutoTrack class]] pathForResource:@"FTAutoTrack" ofType:@"bundle"]];
               //文件路径
        NSString *jsonPath = [sensorsBundle pathForResource:@"ft_autotrack_viewcontroller_blacklist.json" ofType:nil];


        NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
        @try {
            NSArray *blacklistedViewControllerClassNames = [NSJSONSerialization JSONObjectWithData:jsonData  options:NSJSONReadingAllowFragments  error:nil];
            blacklistedClasses = [NSSet setWithArray:blacklistedViewControllerClassNames];
        } @catch(NSException *exception) {  // json加载和解析可能失败
            ZYLog(@"%@ error: %@", self, exception);
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
-(void)addDBWithData:(NSDictionary *)data{
    if (self.lastSentDate) {
        NSDate* now = [NSDate date];
        NSTimeInterval time = [now timeIntervalSinceDate:self.lastSentDate];
        if (time>10) {
        //待处理通知
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
