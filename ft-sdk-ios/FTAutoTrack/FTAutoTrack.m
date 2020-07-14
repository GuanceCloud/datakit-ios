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
#import "FTLog.h"
#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "FTBaseInfoHander.h"
#import <objc/runtime.h>
#import "FTMobileConfig.h"
#import "FTMobileAgent.h"
#import "FTAutoTrackVersion.h"
#import "BlacklistedVCClassNames.h"
#import "FTConstants.h"
#import "FTMobileAgent+Private.h"
#import "NSString+FTAdd.h"
#define WeakSelf __weak typeof(self) weakSelf = self;

@interface FTAutoTrack()
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, assign) long long preFlowTime;
@property (nonatomic, copy)  NSString *flowId;
@property (nonatomic, copy)  NSString *preOpenName;
@property (nonatomic, strong) NSMutableArray *aspectTokenAry;
@property (nonatomic, assign) CFAbsoluteTime launchTime;
@end
@implementation FTAutoTrack
-(instancetype)init{
    self = [super init];
    if (self) {
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
                               selector:@selector(appDidBecomeActiveNotification:)
                                   name:UIApplicationDidBecomeActiveNotification
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
- (void)appDidBecomeActiveNotification:(NSNotification *)notification{
    CFAbsoluteTime intervalTime = (CFAbsoluteTimeGetCurrent() - self.launchTime);
    if ((int)intervalTime>10) {
     [self track:FT_AUTO_TRACK_OP_LAUNCH withCpn:nil WithClickView:nil];
    }
     self.launchTime = CFAbsoluteTimeGetCurrent();
}

#pragma mark ========== 控制器的生命周期 ==========
- (void)logViewControllerLifeCycle{
    id<ZY_AspectToken> viewOpen =[UIViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController * vc = [info instance];
        vc.viewLoadStartTime =CFAbsoluteTimeGetCurrent();
    } error:nil];
    WeakSelf
    id<ZY_AspectToken> lifeOpen = [UIViewController aspect_hookSelector:@selector(viewDidAppear:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController * vc = [info instance];
        if (vc.viewLoadStartTime) {
            float loadTime = (CFAbsoluteTimeGetCurrent() - vc.viewLoadStartTime);
            vc.viewLoadStartTime = 0;
            [weakSelf track:FT_AUTO_TRACK_OP_OPEN withCpn:vc WithClickView:nil index:nil duration:loadTime];
            [weakSelf track:FT_AUTO_TRACK_OP_ENTER withCpn:vc WithClickView:nil];
        }
        [weakSelf track:FT_AUTO_TRACK_OP_ENTER withCpn:vc WithClickView:nil];
        [weakSelf flowOpenTrack:vc];
    } error:nil];
    id<ZY_AspectToken> lifeClose = [UIViewController aspect_hookSelector:@selector(viewDidDisappear:) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController *tempVC = (UIViewController *)info.instance;
        
        [weakSelf track:FT_AUTO_TRACK_OP_LEAVE withCpn:tempVC WithClickView:nil];
    } error:nil];
    [self.aspectTokenAry addObjectsFromArray:@[viewOpen,lifeOpen,lifeClose]];
    
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
    NSString *parent = self.preOpenName;
    NSString *name =NSStringFromClass(vc.class);
    self.preOpenName = name;
    if ([[[FTMobileAgent sharedInstance] getFlowChartDescDict].allKeys containsObject:name]) {
        name =[[FTMobileAgent sharedInstance] getFlowChartDescDict][name];
    }
    if ([[[FTMobileAgent sharedInstance] getFlowChartDescDict].allKeys containsObject:parent]) {
        parent =[[FTMobileAgent sharedInstance] getFlowChartDescDict][parent];
    }
    long  duration;
    long long tm =[FTBaseInfoHander ft_getCurrentTimestamp];
    if (self.preFlowTime==0) {
        duration = 0;
    }else{
        duration = (long)((tm-self.preFlowTime)/1000);
    }
    self.preFlowTime = tm;
    [[FTMobileAgent sharedInstance] flowTrack:FT_FLOW_CHART_PRODUCT traceId:self.flowId name:name parent:parent tags:nil duration:duration field:nil withTrackType:FTTrackTypeAuto];
}

#pragma mark ========== UITableView\UICollectionView的点击事件 ==========
- (void)logTableViewCollectionView{
    WeakSelf
    id<ZY_AspectToken> tableToken =[UITableView aspect_hookSelector:@selector(setDelegate:)
                                                        withOptions:ZY_AspectPositionAfter
                                                         usingBlock:^(id<ZY_AspectInfo> aspectInfo,id target) {
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

#pragma mark ========== button,Gesture的点击事件 ==========
- (void)logTargetAction{
    WeakSelf
    void (^aspectHookBlock)(id<ZY_AspectInfo> aspectInfo, id target, SEL action) = ^(id<ZY_AspectInfo> aspectInfo, id target, SEL action){
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
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:[ges.view ft_getCurrentViewController] WithClickView:ges.view];
            return;
        }else if([from isKindOfClass:NSClassFromString(@"_UIButtonBarButton")]){
            //UIBarButtonItem 点击
            UIView *view = from;
            UIViewController *vc =[view ft_getCurrentViewController];
            if ([vc isKindOfClass:UINavigationController.class]) {
                UINavigationController *nav =(UINavigationController *)vc;
                vc = [nav.viewControllers firstObject];
            }
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:vc WithClickView:view];
            return;
        }else if ([from isKindOfClass:UIView.class]) {
            NSString *className = NSStringFromClass([to class]);
            //因为UITabBar点击会调用 _buttonDown：\ _buttonUp:\_sendAction:withEvent: 三个方法，会产生重复数据 所以只抓取UITabBar 的_buttonDown：方法 来记录一次UITabBar点击
            if ([to isKindOfClass:[UITabBar class]] && ![NSStringFromSelector(action) isEqualToString:@"_buttonDown:"]) {
                return;
            }
            if (![to isKindOfClass:UIViewController.class]&&![to isKindOfClass:UIView.class]) {
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
    if (self.config.whiteViewClass.count>0 && [self isViewTypeWhite:view] == NO) {
        return  NO;
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
    if (self.config.whiteVCList.count > 0 && [self isWhiteListContainsViewController:viewController] == NO) {
        return NO;
    }
    return !([self isBlackListContainsViewController:viewController]||[self isUserSetBlackListContainsViewController:viewController]);;
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
    [self track:op withCpn:cpn WithClickView:view index:nil duration:0];
}
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view index:(NSIndexPath *)indexPath{
    [self track:op withCpn:cpn WithClickView:view index:indexPath duration:0];
}
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view index:(NSIndexPath *)indexPath duration:(float)duration{
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
        NSMutableDictionary *tags = @{FT_AUTO_TRACK_EVENT_ID:[op ft_md5HashToUpper32Bit]}.mutableCopy;
        NSMutableDictionary *field = @{FT_AUTO_TRACK_EVENT:op
        }.mutableCopy;
        NSString *current = nil;
        if ([cpn isKindOfClass:UIView.class]) {
            current = NSStringFromClass([cpn ft_getCurrentViewController].class);
        }else if ([cpn isKindOfClass:UIViewController.class]){
            current = NSStringFromClass([cpn class]);
        }
        FTLoggingBean *bean = [FTLoggingBean new];
        if ([op isEqualToString:FT_AUTO_TRACK_OP_OPEN]) {
            if(!self.config.eventFlowLog){
                return;
            }
            bean.duration = [NSNumber numberWithInt:duration*1000*1000];
        }
        NSMutableDictionary *content = @{FT_AUTO_TRACK_EVENT:op}.mutableCopy;
        bean.measurement = FT_USER_AGENT;
        bean.source = self.config.traceServiceName;
        bean.operationName = [NSString stringWithFormat:@"%@/%@",op,FT_AUTO_TRACK_EVENT];
        if (![op isEqualToString:FT_AUTO_TRACK_OP_LAUNCH]) {
            [tags setObject:[UIViewController ft_getRootViewController] forKey:FT_AUTO_TRACK_ROOT_PAGE_NAME];
            ZYDESCLog(@"current_page_name : %@",current);
            NSString *pageDesc = FT_NULL_VALUE;
            [tags setValue:current forKey:FT_AUTO_TRACK_CURRENT_PAGE_NAME];
            [content setValue:current forKey:FT_AUTO_TRACK_CURRENT_PAGE_NAME];
            if (current && [[[FTMobileAgent sharedInstance] getPageDescDict].allKeys containsObject:current]) {
                pageDesc =[[FTMobileAgent sharedInstance] getPageDescDict][current];
            }
            [field setValue:pageDesc forKey:FT_AUTO_TRACK_PAGE_DESC];
            ZYDESCLog(@"page_desc : %@",pageDesc);
            if ([op isEqualToString:FT_AUTO_TRACK_OP_CLICK]&&[view isKindOfClass:UIView.class]) {
                UIView *vtpView = view;
                NSString *vtp =[view ft_getParentsView];
                if(vtpView.vtpAddIndexPath&& indexPath){
                    vtp= [vtp stringByAppendingFormat:@"/section[%@]/row[%@]",@(indexPath.section).stringValue,@(indexPath.row).stringValue];
                }
                ZYDESCLog(@"vtp : %@",vtp);
                [tags setValue:vtp forKey:FT_AUTO_TRACK_VTP];
                [field setValue:[vtp ft_md5HashToUpper32Bit] forKey:FT_AUTO_TRACK_VTP_ID];
                NSString *vtpDesc = FT_NULL_VALUE;
                if ([[FTMobileAgent sharedInstance] getPageVtpDescEnabled]) {
                    if(vtpView.viewVtpDescID.length>0){
                        vtpDesc = vtpView.viewVtpDescID;
                    }else if ([[[FTMobileAgent sharedInstance] getVtpDescDict].allKeys containsObject:vtp]) {
                        vtpDesc = [[FTMobileAgent sharedInstance] getVtpDescDict][vtp];
                    }
                }
                ZYDESCLog(@"vtpDesc : %@",vtpDesc);
                [field setValue:vtpDesc forKey:FT_AUTO_TRACK_VTP_DESC];
                [content setValue:vtp forKey:FT_AUTO_TRACK_VTP_TREE_PATH];
            }
        }
        bean.content = [FTBaseInfoHander ft_convertToJsonData:content];
        if(self.config.eventFlowLog){
            [[FTMobileAgent sharedInstance] loggingBackground:bean];
        }
        //让 FTMobileAgent 处理数据添加问题 在 FTMobileAgent 里处理添加实时监控线tag
        [[FTMobileAgent sharedInstance] trackBackground:FT_AUTOTRACK_MEASUREMENT tags:tags field:field withTrackType:FTTrackTypeAuto];
    } @catch (NSException *exception) {
        ZYDebug(@" error: %@", exception);
    }
}
-(void)dealloc{
    [self remove];
}
@end
