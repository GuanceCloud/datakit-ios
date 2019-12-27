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
    if (self.config.autoTrackEventType & FTAutoTrackEventTypeAppEnd) {
        [notificationCenter addObserver:self
        selector:@selector(appWillTerminateNotification:)
               name:UIApplicationWillTerminateNotification
             object:nil];
    }
    if (self.config.autoTrackEventType & FTAutoTrackEventTypeAppClick) {
        [self logTableViewCollectionView];
        [self logTargetAction];
    }
    if (self.config.autoTrackEventType & FTAutoTrackEventTypeAppViewScreen) {
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
           if (![self judgeWhiteAndBlackWithViewController:vc]) {
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
    if( [self isAutoTrackUI:UITableView.class] && [self isAutoTrackUI:UITableViewCell.class]){
     NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
     [notificationCenter addObserver:self
                                     selector:@selector(tableViewSelectionDidChangeNotification:)
                                            name:UITableViewSelectionDidChangeNotification
                                          object:nil];
    }
     if( [self isAutoTrackUI:UICollectionView.class] && [self isAutoTrackUI:UICollectionViewCell.class]){
     [UICollectionView aspect_hookSelector:@selector(setDelegate:)
           withOptions:ZY_AspectPositionAfter
                           usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
         [target aspect_hookSelector:@selector(collectionView:didSelectItemAtIndexPath:)
          withOptions:ZY_AspectPositionBefore
           usingBlock:^(id<ZY_AspectInfo> aspectInfo, UICollectionView *collectionView, NSIndexPath *indexPath) {
                UIViewController *vcclass;
                if ([target isKindOfClass:[UIViewController class]]) {
                    vcclass  = target;
                }else if([target isKindOfClass:[UIView class]]){
                    vcclass  = [target zy_getCurrentViewController];
                }
             if (![self judgeWhiteAndBlackWithViewController:vcclass]) {
                 return ;
             }
            NSDictionary *data =@{@"cpn":NSStringFromClass(vcclass.class),
                                                 @"rpn":[UIViewController zy_getRootViewController],
                                                 @"op":@"click",
                                                 @"opdata":@{@"vtp":[collectionView zy_getParentsView]},
                                                };
             ZYDebug(@"data == %@",data);

         } error:NULL];
         
     }error:nil];
     }
   

}
- (void)tableViewSelectionDidChangeNotification:(NSNotification *)notification{
    UITableView *tableview = notification.object;
    UIViewController *current = [tableview zy_getCurrentViewController];
    if([self judgeWhiteAndBlackWithViewController:current]){
    NSDictionary *data =@{@"cpn":NSStringFromClass(current.class),
                                      @"rpn":[UIViewController zy_getRootViewController],
                                      @"op":@"click",
                                      @"opdata":@{@"vtp":[tableview zy_getParentsView]},
                                     };
    [self addDBWithData:data];
    ZYDebug(@"tableViewSelectionDidChangeNotification == %@",data);
    }
}
#pragma mark ========== button,Gesture的点击事件 ==========
- (void)logTargetAction{
    if ([self isAutoTrackUI:UIButton.class]) {
        [UIButton aspect_hookSelector:@selector(addTarget:action:forControlEvents:)
             withOptions:ZY_AspectPositionAfter
              usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action, UIControlEvents controlEvents) {

                  if ([aspectInfo.instance isKindOfClass:[UIButton class]]) {

                      UIButton *button = aspectInfo.instance;
                      button.accessibilityHint = NSStringFromSelector(action);
                  }
              } error:NULL];
          [UIControl aspect_hookSelector:@selector(beginTrackingWithTouch:withEvent:)
          withOptions:ZY_AspectPositionBefore
           usingBlock:^(id<ZY_AspectInfo> aspectInfo, UITouch *touch, UIEvent *event) {

               if ([aspectInfo.instance isKindOfClass:[UIButton class]]) {

                   UIButton *button = aspectInfo.instance;
                   id object =  [button.allTargets anyObject];
                   NSString *className = NSStringFromClass([object class]);
                  if (![self judgeWhiteAndBlackWithViewController:object]) {
                       return ;
                   }
                   NSDictionary *data =@{@"cpn":className,
                                         @"rpn":[UIViewController zy_getRootViewController],
                                         @"op":@"click",
                                         @"opdata":@{@"vtp":[button zy_getParentsView]},
                                         };
                    [self addDBWithData:data];
                    ZYDebug(@"data == %@",data);
               }
           } error:NULL];
    }

    //待处理：仅可以实现
    [UIGestureRecognizer aspect_hookSelector:@selector(addTarget:action:)
      withOptions:ZY_AspectPositionAfter
       usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action) {
        if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]]) {
            UIGestureRecognizer *ges = aspectInfo.instance;
            if (![self isAutoTrackUI:ges.view.class]) {
                return ;
            }
            ges.accessibilityHint = NSStringFromSelector(action);
            if (![self judgeWhiteAndBlackWithViewController:target]) {
                             return ;
            }
            if ([target isKindOfClass:[UIViewController class]]) {
                [target aspect_hookSelector:action withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                    NSDictionary *data =@{@"cpn":NSStringFromClass([target class]),
                                          @"rpn":[UIViewController zy_getRootViewController],
                                          @"op":@"click",
                                          @"opdata":@{@"vtp":[ges.view zy_getParentsView]},
                                                        };
                    [self addDBWithData:data];
                     ZYDebug(@"data == %@",data);

                } error:nil];
            }
            
        }
       } error:NULL];
       [UIGestureRecognizer aspect_hookSelector:@selector(initWithTarget:action:)
            withOptions:ZY_AspectPositionAfter
             usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action) {
              if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]]) {
                  UIGestureRecognizer *ges = aspectInfo.instance;
                  if (![self isAutoTrackUI:ges.view.class]) {
                      return ;
                  }
                  ges.accessibilityHint = NSStringFromSelector(action);
                  if (![self judgeWhiteAndBlackWithViewController:target]) {
                                   return ;
                  }
                  if ([target isKindOfClass:[UIViewController class]]) {
                      [target aspect_hookSelector:action withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                          NSDictionary *data =@{@"cpn":NSStringFromClass([target class]),
                                                @"rpn":[UIViewController zy_getRootViewController],
                                                @"op":@"click",
                                                @"opdata":@{@"vtp":[ges.view zy_getParentsView]},
                                                              };
                          [self addDBWithData:data];
                           ZYDebug(@"data == %@",data);

                      } error:nil];
                  }
                  
              }
             } error:NULL];
     
      
}
- (BOOL)isAutoTrackUI:(Class )view{
    if (self.config.whiteViewClass.count == 0 && self.config.blackViewClass.count == 0) {
        return YES;
    }
    if (self.config.whiteViewClass.count>0) {
      return  [self isViewTypeWhite:view];
    }
    
    return ![self isViewTypeIgnored:view];
    
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
    NSSet *blacklistedClasses = [[NSSet alloc]initWithArray:self.config.blackVCList];
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
       
        NSBundle *sensorsBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[FTAutoTrack class]] pathForResource:@"FTAutoTrack" ofType:@"bundle"]];
               //文件路径
        NSString *jsonPath = [sensorsBundle pathForResource:@"ft_autotrack_viewcontroller_blacklist.json" ofType:nil];


        NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
        @try {
            NSArray *blacklistedViewControllerClassNames = [NSJSONSerialization JSONObjectWithData:jsonData  options:NSJSONReadingAllowFragments  error:nil];
            [blacklistedClasses setByAddingObjectsFromSet:[NSSet setWithArray:blacklistedViewControllerClassNames]];
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
-(void)addDBWithData:(NSDictionary *)data{
    @try {
          RecordModel *model = [RecordModel new];
          model.tm = [ZYBaseInfoHander getCurrentTimestamp];
          model.data =[ZYBaseInfoHander convertToJsonData:data];
          [[ZYTrackerEventDBTool sharedManger] insertItemWithItemData:model];
    } @catch (NSException *exception) {
         ZYDebug(@" error: %@", exception);
    }
    
}
@end
