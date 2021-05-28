//
//  FTTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/11/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTTrack.h"
#import "FTConstants.h"
#import <UIKit/UIKit.h>
#import "ZYAspects.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTLog.h"
#import "BlacklistedVCClassNames.h"
#import "FTMobileAgent+Private.h"
#import "NSString+FTAdd.h"
#import "NSDate+FTAdd.h"
#import "UIView+FTAutoTrack.h"
#import "FTMonitorManager.h"
#import "FTJSONUtil.h"
#define WeakSelf __weak typeof(self) weakSelf = self;
static NSString * const FT_AUTO_TRACK_OP_ENTER  = @"enter";
static NSString * const FT_AUTO_TRACK_OP_LEAVE  = @"leave";
static NSString * const FT_AUTO_TRACK_OP_CLICK  = @"click";
static NSString * const FT_AUTO_TRACK_ROOT_PAGE_NAME = @"root_page_name";
static NSString * const FT_AUTO_TRACK_CURRENT_PAGE_NAME = @"current_page_name";
static NSString * const FT_AUTO_TRACK_VTP = @"vtp";
static NSString * const FT_AUTO_TRACK_OP_OPEN  = @"open";
static NSString * const FT_AUTO_TRACK_EVENT_ID = @"event_id";
static NSString * const FT_AUTO_TRACK_VTP_TREE_PATH = @"view_tree_path";

@interface FTTrack(){
    BOOL _appRelaunched;          // App 从后台恢复
    //进入非活动状态，比如双击 home、系统授权弹框
    BOOL _applicationWillResignActive;
}
@property (nonatomic,assign) CFTimeInterval launch;
@property (nonatomic, strong) NSMutableArray *aspectTokenAry;
@property (nonatomic, weak) UIViewController *previousTrackViewController;
@property (nonatomic,copy,readwrite) NSString *currentViewid;
@property (nonatomic, strong) NSDate *launchTime;

@end
@implementation FTTrack
-(instancetype)init{
    self = [super init];
    if (self) {
        _appRelaunched = NO;
        _launchTime = [NSDate date];
        _aspectTokenAry = [NSMutableArray new];
        [self startHook];
    }
    return  self;
}
- (void)startHook{
    [self applicationLaunch];
    [self logViewControllerLifeCycle];
    [self logTableViewCollectionView];
    [self logTargetAction];
}
- (void)applicationLaunch{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    // 应用生命周期通知
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
}
- (void)applicationWillEnterForeground:(NSNotification *)notification{
    if (_appRelaunched){
        self.launchTime = [NSDate date];
    }
}
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    @try {
        if (_applicationWillResignActive) {
            _applicationWillResignActive = NO;
            return;
        }
        if (self.rumActionDelegate && [self.rumActionDelegate respondsToSelector:@selector(ftApplicationDidBecomeActive:)]) {
            [self.rumActionDelegate ftApplicationDidBecomeActive:_appRelaunched];
        }
        _appRelaunched = YES;
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)applicationDidEnterBackground:(NSNotification *)notification{
    if (!_applicationWillResignActive) {
        return;
    }
    _applicationWillResignActive = NO;
}
- (void)applicationWillResignActive:(NSNotification *)notification {
    @try {
        _applicationWillResignActive = YES;
        if (self.rumActionDelegate && [self.rumActionDelegate respondsToSelector:@selector(ftApplicationWillResignActive)]) {
            [self.rumActionDelegate ftApplicationWillResignActive];
        }
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"applicationWillResignActive exception %@",exception);
    }
}
- (void)logViewControllerLifeCycle{
    WeakSelf
    id<ZY_AspectToken> viewLoad = [UIViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController * vc = [info instance];
        vc.ft_viewLoadStartTime =[NSDate date];
    } error:nil];
    
    id<ZY_AspectToken> viewAppear = [UIViewController aspect_hookSelector:@selector(viewDidAppear:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController * vc = [info instance];
        if(![weakSelf isBlackListContainsViewController:vc]){
            if(vc.ft_viewLoadStartTime){
                NSNumber *loadTime = [[NSDate date] ft_nanotimeIntervalSinceDate:vc.ft_viewLoadStartTime];
                vc.ft_loadDuration = loadTime;
                vc.ft_viewLoadStartTime = nil;
                [weakSelf trackOpenWithCpn:vc duration:loadTime];
            }else{
                NSNumber *loadTime = @0;
                vc.ft_loadDuration = loadTime;
            }
            if(weakSelf.previousTrackViewController != vc){
                weakSelf.previousTrackViewController = vc;
                [weakSelf track:FT_AUTO_TRACK_OP_ENTER withCpn:vc WithClickView:nil];
            }

            if (self.rumActionDelegate&&[self.rumActionDelegate respondsToSelector:@selector(ftViewDidAppear:)]) {
                [self.rumActionDelegate ftViewDidAppear:vc];
            }
            
        }
    } error:nil];
    id<ZY_AspectToken> lifeClose = [UIViewController aspect_hookSelector:@selector(viewDidDisappear:) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController *tempVC = (UIViewController *)info.instance;
        if([weakSelf isBlackListContainsViewController:tempVC]){
            return;
        }
        if (self.rumActionDelegate&&[self.rumActionDelegate respondsToSelector:@selector(ftViewDidDisappear:)]) {
            [self.rumActionDelegate ftViewDidDisappear:tempVC];
        }
        [weakSelf track:FT_AUTO_TRACK_OP_LEAVE withCpn:tempVC WithClickView:nil];
    } error:nil];
    [self.aspectTokenAry addObjectsFromArray:@[viewLoad,viewAppear,lifeClose]];
}
- (void)logTableViewCollectionView{
    WeakSelf
    id<ZY_AspectToken> tableToken =[UITableView aspect_hookSelector:@selector(setDelegate:)
                                                        withOptions:ZY_AspectPositionAfter
                                                         usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
        if ([weakSelf isBlackListContainsViewController:target]) {
            return;
        }
        if(![target respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]){
            return;
        }
        [target aspect_hookSelector:@selector(tableView:didSelectRowAtIndexPath:)
                        withOptions:ZY_AspectPositionBefore
                         usingBlock:^(id<ZY_AspectInfo> aspectInfo, UITableView *tableView, NSIndexPath *indexPath) {
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:tableView index:indexPath];
        } error:NULL];
        
    }error:nil];
    
    [self.aspectTokenAry addObject:tableToken];
    id<ZY_AspectToken> collectionToken =[UICollectionView aspect_hookSelector:@selector(setDelegate:)
                                                                  withOptions:ZY_AspectPositionAfter
                                                                   usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
        if([NSStringFromClass([target class]) isEqualToString:@"TUICandidateGrid"]){
            return;
        }
        if ([weakSelf isBlackListContainsViewController:target]) {
            return;
        }
        if(![target respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]){
            return;
        }
        [target aspect_hookSelector:@selector(collectionView:didSelectItemAtIndexPath:)
                        withOptions:ZY_AspectPositionBefore
                         usingBlock:^(id<ZY_AspectInfo> aspectInfo, UICollectionView *collectionView, NSIndexPath *indexPath) {
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:collectionView index:indexPath];
        } error:NULL];
        
    }error:nil];
    [self.aspectTokenAry addObject:collectionToken];
}
- (void)logTargetAction{
    WeakSelf
    void (^aspectHookBlock)(id<ZY_AspectInfo> aspectInfo, id target, SEL action) = ^(id<ZY_AspectInfo> aspectInfo, id target, SEL action){
        if ([weakSelf isBlackListContainsViewController:target]) {
            return;
        }
        //忽略iOS13之后 系统为UITableView添加的 _handleKnobLongPressGesture：
        if ([aspectInfo.instance isKindOfClass:[UIGestureRecognizer class]] && ![NSStringFromSelector(action) isEqualToString:@"_handleKnobLongPressGesture:"]) {
            UIGestureRecognizer *ges = aspectInfo.instance;
            if ([target isKindOfClass:[UIViewController class]]||[target isKindOfClass:UIView.class]) {
                Class vcClass = [target class];
                [vcClass aspect_hookSelector:action withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo) {
                    if (ges.state != UIGestureRecognizerStateEnded) {
                        return;
                    }
                    [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:aspectInfo.instance WithClickView:ges.view];
                } error:nil];
            }
        }
    };
    id<ZY_AspectToken> gesToken =  [UITapGestureRecognizer aspect_hookSelector:@selector(addTarget:action:)
                                                                   withOptions:ZY_AspectPositionAfter
                                                                    usingBlock:aspectHookBlock error:NULL];
    [self.aspectTokenAry addObject:gesToken];
    
    id<ZY_AspectToken> gesToken3 = [UITapGestureRecognizer aspect_hookSelector:@selector(initWithTarget:action:)
                                                                   withOptions:ZY_AspectPositionAfter
                                                                    usingBlock:aspectHookBlock error:NULL];
    [self.aspectTokenAry addObject:gesToken3];
    
    id<ZY_AspectToken> gesToken2 =[UILongPressGestureRecognizer aspect_hookSelector:@selector(addTarget:action:)
                                                                        withOptions:ZY_AspectPositionAfter
                                                                         usingBlock:aspectHookBlock error:NULL];
    [self.aspectTokenAry addObject:gesToken2];
    
    id<ZY_AspectToken> gesToken4 = [UILongPressGestureRecognizer aspect_hookSelector:@selector(initWithTarget:action:)
                                                                         withOptions:ZY_AspectPositionAfter
                                                                          usingBlock:aspectHookBlock error:NULL];
    [self.aspectTokenAry addObject:gesToken4];
    
    id<ZY_AspectToken> clickToken = [UIApplication aspect_hookSelector:@selector(sendAction:to:from:forEvent:) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> aspectInfo, SEL action,id to,id  from,UIEvent *event) {
        //UITextField、UITextView点击
        if ([from isKindOfClass:NSClassFromString(@"UITextMultiTapRecognizer")]) {
            UIGestureRecognizer *ges = from;
            if (ges.state != UIGestureRecognizerStateEnded) {
                return;
            }
            UIViewController *vc = [ges.view ft_currentViewController];
            if ([weakSelf isBlackListContainsViewController:vc]) {
                return;
            }
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:vc WithClickView:ges.view];
            return;
        }else if([from isKindOfClass:NSClassFromString(@"_UIButtonBarButton")]){
            //UIBarButtonItem 点击
            UIView *view = from;
            UIViewController *vc =[view ft_currentViewController];
            if ([vc isKindOfClass:UINavigationController.class]) {
                UINavigationController *nav =(UINavigationController *)vc;
                vc = [nav.viewControllers firstObject];
            }
            if ([weakSelf isBlackListContainsViewController:vc]) {
                return;
            }
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:vc WithClickView:view];
            return;
        }else if ([from isKindOfClass:UIView.class]) {
            //因为UITabBar点击会调用 _buttonDown：\ _buttonUp:\_sendAction:withEvent: 三个方法，会产生重复数据 所以只抓取UITabBar 的_buttonDown：方法 来记录一次UITabBar点击
            if ([to isKindOfClass:[UITabBar class]] && ![NSStringFromSelector(action) isEqualToString:@"_buttonDown:"]) {
                return;
            }
            if (![to isKindOfClass:UIViewController.class]&&![to isKindOfClass:UIView.class]) {
                return;
            }
            UIViewController *vc;
            if (![to isKindOfClass:UIViewController.class]) {
                vc = [to ft_currentViewController];
            }else{
                vc = to;
            }
            if ([weakSelf isBlackListContainsViewController:vc]) {
                return;
            }
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:vc WithClickView:from];
            
        }
    } error:NULL];
    [self.aspectTokenAry addObject:clickToken];
}
- (BOOL)isBlackListContainsViewController:(UIViewController *)viewController {
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
        if (blackClass && [viewController isKindOfClass:blackClass]) {
            isContains = YES;
            *stop = YES;
        }
    }];
    return isContains;
}
//-(void)trackStartWithTime:(NSDate *)time{
//    @try {
//        [[FTMobileAgent sharedInstance] trackStartWithViewLoadTime:time];
//    } @catch (NSException *exception) {
//        ZYErrorLog(@" error: %@", exception);
//    }
//}
-(void)trackOpenWithCpn:(id<FTAutoTrackViewControllerProperty>)cpn duration:(NSNumber *)duration{
    @try {
        FTMobileAgent *instance = [FTMobileAgent sharedInstance];
        if (instance.config.eventFlowLog) {
            NSString *name = NSStringFromClass(cpn.class);
            NSString *view_id = cpn.ft_viewControllerId;
            NSString *parent = cpn.ft_parentVC;
            NSMutableDictionary *tags = @{@"view_id":view_id,
                                          @"view_name":name,
                                          @"view_referrer":parent,
            }.mutableCopy;
            NSMutableDictionary *fields = @{
                @"duration":duration,
            }.mutableCopy;
            if (instance.config.monitorInfoType & FTMonitorInfoTypeFPS) {
                NSNumber *fps = [[FTMonitorManager sharedInstance] fpsValue];
                if (fps.intValue != 0) {
                    fields[@"view_fps"] =fps;
                }
            }
            int apdexlevel = duration.intValue/1000000000 <=9 ? : 9;
            tags[@"app_apdex_level"] = [NSNumber numberWithInt:apdexlevel];
            NSMutableDictionary *content = @{FT_KEY_EVENT:FT_AUTO_TRACK_OP_OPEN}.mutableCopy;
            [content setValue:NSStringFromClass([cpn class]) forKey:FT_AUTO_TRACK_CURRENT_PAGE_NAME];
            NSDictionary *tag = @{FT_KEY_OPERATION:[NSString stringWithFormat:@"%@/%@",FT_AUTO_TRACK_OP_OPEN,FT_KEY_EVENT]};
            NSDictionary *field = @{FT_KEY_DURATION:duration};
            [instance loggingWithType:FTAddDataNormal status:FTStatusInfo content:[FTJSONUtil convertToJsonData:content] tags:tag field:field tm:[[NSDate date] ft_dateTimestamp]];
        }
        
    } @catch (NSException *exception) {
        ZYErrorLog(@" error: %@", exception);
    }
}
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view{
    [self track:op withCpn:cpn WithClickView:view index:nil];
}
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view index:(NSIndexPath *)indexPath{
    if ([op isEqualToString:FT_AUTO_TRACK_OP_CLICK]) {
        if (self.rumActionDelegate && [self.rumActionDelegate respondsToSelector:@selector(ftClickView:)]) {
            [self.rumActionDelegate ftClickView:view];
        }
    }
    
    FTMobileAgent *agent = [FTMobileAgent sharedInstance];
    if(!agent.config.eventFlowLog){
        return;
    }
    @try {
        //事件日志
        NSMutableDictionary *content = [NSMutableDictionary new];
        if (![op isEqualToString:FT_AUTO_TRACK_OP_LAUNCH]) {
            NSString *current = nil;
            if ([cpn isKindOfClass:UIView.class]) {
                current = NSStringFromClass([cpn ft_currentViewController].class);
            }else if ([cpn isKindOfClass:UIViewController.class]){
                current = NSStringFromClass([cpn class]);
            }
            [content setValue:current forKey:FT_AUTO_TRACK_CURRENT_PAGE_NAME];
            //点击事件 添加视图树
            if ([op isEqualToString:FT_AUTO_TRACK_OP_CLICK]&&[view isKindOfClass:UIView.class]) {
                NSString *vtp =[view ft_parentsView];
                [content setValue:vtp forKey:FT_AUTO_TRACK_VTP_TREE_PATH];
            }
        }
        [content setValue:op forKey:FT_KEY_EVENT];
        NSDictionary *tag =@{FT_KEY_OPERATION:[NSString stringWithFormat:@"%@/%@",op,FT_KEY_EVENT]};
        [agent loggingWithType:FTAddDataNormal status:FTStatusInfo content:[FTJSONUtil convertToJsonData:content] tags:tag field:nil tm:[[NSDate date] ft_dateTimestamp]];
        
    } @catch (NSException *exception) {
        ZYErrorLog(@" error: %@", exception);
    }
}
-(void)dealloc{
    [_aspectTokenAry enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<ZY_AspectToken> token = obj;
        [token remove];
    }];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
