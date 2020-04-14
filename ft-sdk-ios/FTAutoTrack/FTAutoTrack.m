//
//  FTAutoTrack.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTAutoTrack.h"
#import "UIView+FT_CurrentController.h"
#import "UIViewController+FT_RootVC.h"
#import "ZYAspects.h"
#import <UIKit/UIKit.h>
#import "ZYLog.h"
#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHander.h"
#import <objc/runtime.h>
#import "FTMobileConfig.h"
#import "FTMobileAgent.h"
#import "FTAutoTrackVersion.h"
#define WeakSelf __weak typeof(self) weakSelf = self;

NSString * const FT_AUTO_TRACK_OP_ENTER  = @"enter";
NSString * const FT_AUTO_TRACK_OP_LEAVE  = @"leave";
NSString * const FT_AUTO_TRACK_OP_CLICK  = @"click";
NSString * const FT_AUTO_TRACK_OP_LAUNCH = @"launch";

@interface FTAutoTrack()
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, assign) long long preFlowTime;
@property (nonatomic, copy)  NSString *flowId;
@property (nonatomic, copy)  NSString *preOpenName;
@property (nonatomic, strong) NSMutableArray *aspectTokenAry;
@end
@implementation FTAutoTrack
-(instancetype)init{
  self = [super init];
  if (!self) {
       self.preFlowTime = 0;
       self.flowId = [[NSUUID UUID] UUIDString];
  }
  return self;
}
-(void)startWithConfig:(FTMobileConfig *)config{
    config.sdkTrackVersion = SDK_VERSION;
    self.config = config;
}
-(void)setConfig:(FTMobileConfig *)config{
    [self remove];
    self.aspectTokenAry = @[].mutableCopy;
    _config = config;
    [self setLogContent];
}
-(void)setLogContent{
    if (!self.config.enableAutoTrack || self.config.autoTrackEventType &  FTAutoTrackTypeNone) {
        return;
    }
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    if (self.config.autoTrackEventType & FTAutoTrackEventTypeAppLaunch) {
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
    
}
- (void)appDidFinishLaunchingWithOptions:(NSNotification *)notification{
    
    [self track:FT_AUTO_TRACK_OP_LAUNCH withCpn:nil WithClickView:nil];
    
}

#pragma mark ========== 控制器的生命周期 ==========
- (void)logViewControllerLifeCycle{
    WeakSelf
   id<ZY_AspectToken> lifeOpen = [UIViewController aspect_hookSelector:@selector(viewDidAppear:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController * vc = [info instance];
        [weakSelf track:FT_AUTO_TRACK_OP_ENTER withCpn:vc WithClickView:nil];
        [weakSelf flowOpenTrack:vc];
    } error:nil];
   id<ZY_AspectToken> lifeClose = [UIViewController aspect_hookSelector:@selector(viewDidDisappear:) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController *tempVC = (UIViewController *)info.instance;
        
        [weakSelf track:FT_AUTO_TRACK_OP_LEAVE withCpn:tempVC WithClickView:nil];
    } error:nil];
    [self.aspectTokenAry addObjectsFromArray:@[lifeOpen,lifeClose]];

}
- (void)flowOpenTrack:(UIViewController *)vc{
    if (!self.config.enableScreenFlow) {
        return;
    }
    if ([vc isKindOfClass:UINavigationController.class]) {
        return;
    }
    if ([self isBlackListContainsViewController:vc]) {
        return;
    }
    ZYLog(@"superview == %@",vc.view.superview) ;
    NSString *parent = self.preOpenName;
    self.preOpenName = NSStringFromClass(vc.class);
    long long duration;
    long long tm =[FTBaseInfoHander ft_getCurrentTimestamp];
    if (self.preFlowTime==0) {
        duration = 0;
    }else{
        duration = (tm-self.preFlowTime)/1000;
    }
    self.preFlowTime = tm;
    NSString *product = [NSString stringWithFormat:@"$flow_mobile_activity_%@",self.config.product];
    NSMutableDictionary *tags = @{@"$traceId":self.flowId,
                                  @"$name":NSStringFromClass(vc.class)}.mutableCopy;
    if (parent.length>0) {
        [tags setObject:parent forKey:@"$parent"];
    }
    NSDictionary *opdata = @{@"measurement":product,
                                  @"tags":tags,
                                  @"field":@{@"$duration":[NSNumber numberWithLongLong:duration]},
       };
    [[FTMobileAgent sharedInstance] performSelector:@selector(insertDBWithOpdata:op:) withObject:opdata withObject:@"view"];
    
}

#pragma mark ========== UITableView\UICollectionView的点击事件 ==========
- (void)logTableViewCollectionView{
    WeakSelf
   id<ZY_AspectToken> tableToken =[UITableView aspect_hookSelector:@selector(setDelegate:)
                         withOptions:ZY_AspectPositionAfter
                          usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
        [target aspect_hookSelector:@selector(tableView:didSelectRowAtIndexPath:)
                        withOptions:ZY_AspectPositionBefore
                         usingBlock:^(id<ZY_AspectInfo> aspectInfo, UITableView *tableView, NSIndexPath *indexPath) {
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:tableView];
        } error:NULL];
        
    }error:nil];
    
    [self.aspectTokenAry addObject:tableToken];
   id<ZY_AspectToken> collectionToken =[UICollectionView aspect_hookSelector:@selector(setDelegate:)
                              withOptions:ZY_AspectPositionAfter
                               usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
        if ([weakSelf isBlackListContainsViewController:target]) {
            return ;
        }
        [target aspect_hookSelector:@selector(collectionView:didSelectItemAtIndexPath:)
                        withOptions:ZY_AspectPositionBefore
                         usingBlock:^(id<ZY_AspectInfo> aspectInfo, UICollectionView *collectionView, NSIndexPath *indexPath) {
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:collectionView];
        } error:NULL];
        
    }error:nil];
    [self.aspectTokenAry addObject:collectionToken];
    
}

#pragma mark ========== button,Gesture的点击事件 ==========
- (void)logTargetAction{
    WeakSelf
    
   id<ZY_AspectToken> gesToken =  [UIGestureRecognizer aspect_hookSelector:@selector(addTarget:action:)
                                 withOptions:ZY_AspectPositionAfter
                                  usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action) {
        if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]]) {
            UIGestureRecognizer *ges = aspectInfo.instance;
            
            ges.accessibilityHint = NSStringFromSelector(action);
            
            if ([target isKindOfClass:[UIViewController class]]) {
                Class vcClass = [target class];
                [vcClass aspect_hookSelector:action withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                    [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:ges.view];
                    
                } error:nil];
            }
            
        }
    } error:NULL];
    [self.aspectTokenAry addObject:gesToken];
   id<ZY_AspectToken> gesToken2 =[UIGestureRecognizer aspect_hookSelector:@selector(initWithTarget:action:)
                                 withOptions:ZY_AspectPositionAfter
                                  usingBlock:^(id<ZY_AspectInfo> aspectInfo, id target, SEL action) {
        if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]]) {
            UIGestureRecognizer *ges = aspectInfo.instance;
            
            ges.accessibilityHint = NSStringFromSelector(action);
            
            if ([target isKindOfClass:[UIViewController class]]) {
                Class vcClass = [target class];
                
                [vcClass aspect_hookSelector:action withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                    [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:ges.view];
                    
                } error:nil];
            }
            
        }
    } error:NULL];
    [self.aspectTokenAry addObject:gesToken2];

   id<ZY_AspectToken> clickToken = [UIApplication aspect_hookSelector:@selector(sendAction:to:from:forEvent:) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo, SEL action,id to,id  from,UIEvent *event) {
        if ([from isKindOfClass:UIView.class] || [to isKindOfClass:UITabBarController.class]) {
            NSString *className = NSStringFromClass([to class]);
            if ([to isKindOfClass:[UITabBar class]] ) {
                return;
            }
            UIViewController *vc;
            if (![to isKindOfClass:UIViewController.class]) {
                vc = [to ft_getCurrentViewController];
                className = NSStringFromClass([vc class]);
            }else{
                vc = to;
            }
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:vc WithClickView:from];
            
        }
    } error:NULL];
    [self.aspectTokenAry addObject:clickToken];
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
        return !([self isBlackListContainsViewController:viewController]||[self isUserSetBlackListContainsViewController:viewController]);
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
    static NSSet * blacklistedClasses  = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSString *strPath = [[NSBundle mainBundle] pathForResource:@"FTAutoTrack" ofType:@"framework"];
        NSString *bundlePath = [[NSBundle bundleWithPath:strPath] pathForResource:@"FTAutoTrack" ofType:@"bundle"];
        NSString *jsonPath = [[NSBundle bundleWithPath:bundlePath] pathForResource:@"ft_autotrack_viewcontroller_blacklist" ofType:@"json"];
        NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
        
        @try {
            NSArray *blacklistedViewControllerClassNames = [NSJSONSerialization JSONObjectWithData:jsonData  options:NSJSONReadingAllowFragments  error:nil];
            blacklistedClasses = [NSSet setWithArray:blacklistedViewControllerClassNames];
            
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
- (BOOL)isUserSetBlackListContainsViewController:(UIViewController *)viewController {
    NSSet * blacklistedClasses = [NSSet setWithArray:self.config.blackVCList];
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
-(void)remove{
    [self.aspectTokenAry enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<ZY_AspectToken> token = obj;
        [token remove];
    }];
}
#pragma mark ========== 写入数据库操作 ==========
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view{
    //添加判断允许的全埋点类型  以防重置 config 带来的影响
    if (!self.config.enableAutoTrack || self.config.autoTrackEventType &  FTAutoTrackTypeNone) {
        return;
    }
    if ([op isEqualToString:FT_AUTO_TRACK_OP_CLICK] && !(self.config.autoTrackEventType & FTAutoTrackEventTypeAppClick)) {
        return;
    }
    if ([op isEqualToString:FT_AUTO_TRACK_OP_LAUNCH] && !(self.config.autoTrackEventType & FTAutoTrackEventTypeAppLaunch)) {
        return;
    }
    if (([op isEqualToString:FT_AUTO_TRACK_OP_ENTER] || [op isEqualToString:FT_AUTO_TRACK_OP_LEAVE]) && !(self.config.autoTrackEventType & FTAutoTrackEventTypeAppViewScreen)) {
        return;
    }
    if (![self judgeWhiteAndBlackWithViewController:cpn]) {
        return ;
    }
    if (view != nil && ![self isAutoTrackUI:[view class]]) {
        return ;
    }
    @try {
        NSMutableDictionary *tags = [NSMutableDictionary new];
        NSDictionary *field = @{@"event":op};
        NSString *measurement = @"mobile_tracker";
        if (![op isEqualToString:FT_AUTO_TRACK_OP_LAUNCH]) {
            [tags setObject:[UIViewController ft_getRootViewController] forKey:@"root_page_name"];
            if ([cpn isKindOfClass:UIView.class]) {
              [tags addEntriesFromDictionary:@{@"current_page_name":NSStringFromClass([cpn ft_getCurrentViewController].class)}];
            }else if ([cpn isKindOfClass:UIViewController.class]){
              [tags addEntriesFromDictionary:@{@"current_page_name":NSStringFromClass([cpn class])}];
            }
            if ([op isEqualToString:FT_AUTO_TRACK_OP_CLICK]&&[view isKindOfClass:UIView.class]) {
                [tags addEntriesFromDictionary:@{@"vtp":[view ft_getParentsView]}];
            }
        }
        NSMutableDictionary *opdata =  [NSMutableDictionary dictionaryWithDictionary:@{
            @"measurement":measurement,
            @"field":field,
            @"tags":tags
        }];
        //让 FTMobileAgent 处理数据添加问题 在 FTMobileAgent 里处理添加实时监控线tag
        [[FTMobileAgent sharedInstance] performSelector:@selector(insertDBWithOpdata:op:) withObject:opdata withObject:op];
        
    } @catch (NSException *exception) {
        ZYDebug(@" error: %@", exception);
    }
}
-(void)dealloc{
    [self remove];
}
@end
