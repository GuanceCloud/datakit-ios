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
#import "UIViewController+FT_RootVC.h"
#import "FTLog.h"
#import "BlacklistedVCClassNames.h"
#import "FTMobileAgent+Private.h"
#import "NSString+FTAdd.h"
#import "NSDate+FTAdd.h"
#import "UIView+FT_CurrentController.h"
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

@interface FTTrack()
@property (nonatomic,assign) BOOL isLaunched;
@property (nonatomic,assign) CFTimeInterval launch;
@property (nonatomic, strong) NSMutableArray *aspectTokenAry;
@end
@implementation FTTrack
-(instancetype)init{
    self = [super init];
    if (self) {
        _isLaunched = NO;
        [self startHook];
    }
    return  self;
}
- (void)startHook{
    [self logViewControllerLifeCycle];
    [self logTableViewCollectionView];
    [self logTargetAction];
}
- (void)logViewControllerLifeCycle{
    WeakSelf
    id<ZY_AspectToken> viewLoad = [UIViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController * vc = [info instance];
        vc.viewLoadStartTime =CFAbsoluteTimeGetCurrent();
        if(![weakSelf isBlackListContainsViewController:vc]&&vc.viewLoadStartTime){
            [weakSelf track:FT_AUTO_TRACK_OP_ENTER withCpn:vc WithClickView:nil];
        }
    } error:nil];
    
    id<ZY_AspectToken> viewAppear = [UIViewController aspect_hookSelector:@selector(viewDidAppear:) withOptions:ZY_AspectPositionAfter usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController * vc = [info instance];
        if(![weakSelf isBlackListContainsViewController:vc]&&vc.viewLoadStartTime){
            CFTimeInterval time = CFAbsoluteTimeGetCurrent();
            float loadTime = (time - vc.viewLoadStartTime);
            vc.viewLoadStartTime = 0;
            [weakSelf trackOpenWithCpn:vc duration:loadTime];
            if (!weakSelf.isLaunched) {
                [weakSelf trackStartWithTime:CFAbsoluteTimeGetCurrent()];
                weakSelf.isLaunched = YES;
            }
        }
    } error:nil];
    id<ZY_AspectToken> lifeClose = [UIViewController aspect_hookSelector:@selector(viewDidDisappear:) withOptions:ZY_AspectPositionBefore usingBlock:^(id<ZY_AspectInfo> info){
        UIViewController *tempVC = (UIViewController *)info.instance;
        if([weakSelf isBlackListContainsViewController:tempVC]){
            return;
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
            UIViewController *vc = [ges.view ft_getCurrentViewController];
            if ([weakSelf isBlackListContainsViewController:vc]) {
                return;
            }
            [weakSelf track:FT_AUTO_TRACK_OP_CLICK withCpn:vc WithClickView:ges.view];
            return;
        }else if([from isKindOfClass:NSClassFromString(@"_UIButtonBarButton")]){
            //UIBarButtonItem 点击
            UIView *view = from;
            UIViewController *vc =[view ft_getCurrentViewController];
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
-(void)trackStartWithTime:(CFTimeInterval)time{
    @try {
        [[FTMobileAgent sharedInstance] trackStartWithViewLoadTime:time];
    } @catch (NSException *exception) {
        ZYErrorLog(@" error: %@", exception);
    }
}
-(void)trackOpenWithCpn:(id)cpn duration:(float)duration{
    @try {
        FTMobileAgent *instance = [FTMobileAgent sharedInstance];
        if ([instance judgeIsTraceSampling]) {
            NSString *name = NSStringFromClass([cpn class]);
            NSString *view_id = [name ft_md5HashToUpper32Bit];
            NSString *parent = [(UIViewController *)cpn ft_getParentVC];
            NSMutableDictionary *tags = @{@"view_id":view_id,
                                   @"view_name":name,
                                   @"view_parent":parent,
            }.mutableCopy;
            NSMutableDictionary *fields = @{
                @"view_load":[NSNumber numberWithInt:duration*1000*1000],
            }.mutableCopy;
            if (instance.config.monitorInfoType & FTMonitorInfoTypeFPS) {
                NSNumber *fps = [[FTMonitorManager sharedInstance] getFPSValue];
                if (fps.intValue != 0) {
                    fields[@"view_fps"] =fps;
                }
            }
            int apdexlevel = duration > 9 ? 9 : duration;
            tags[@"app_apdex_level"] = [NSNumber numberWithInt:apdexlevel];
            [instance rumTrack:FT_RUM_APP_VIEW tags:tags fields:fields tm:[[NSDate date] ft_dateTimestamp]];
            [instance rumTrackES:FT_TYPE_VIEW terminal:FT_TERMINAL_APP tags:tags fields:fields];
            if (instance.config.eventFlowLog) {
                NSMutableDictionary *content = @{FT_KEY_EVENT:FT_AUTO_TRACK_OP_OPEN}.mutableCopy;
                [content setValue:NSStringFromClass([cpn class]) forKey:FT_AUTO_TRACK_CURRENT_PAGE_NAME];
                NSDictionary *tag = @{FT_KEY_OPERATIONNAME:[NSString stringWithFormat:@"%@/%@",FT_AUTO_TRACK_OP_OPEN,FT_KEY_EVENT]};
                NSDictionary *field = @{FT_KEY_DURATION:[NSNumber numberWithInt:duration*1000]};
                [instance loggingWithType:FTAddDataNormal status:FTStatusInfo content:[FTJSONUtil ft_convertToJsonData:content] tags:tag field:field tm:[[NSDate date] ft_dateTimestamp]];
            }
        }
    } @catch (NSException *exception) {
        ZYErrorLog(@" error: %@", exception);
    }
}
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view{
    [self track:op withCpn:cpn WithClickView:view index:nil];
}
-(void)track:(NSString *)op withCpn:( id)cpn WithClickView:( id)view index:(NSIndexPath *)indexPath{
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
                current = NSStringFromClass([cpn ft_getCurrentViewController].class);
            }else if ([cpn isKindOfClass:UIViewController.class]){
                current = NSStringFromClass([cpn class]);
            }
            [content setValue:current forKey:FT_AUTO_TRACK_CURRENT_PAGE_NAME];
            //点击事件 添加视图树
            if ([op isEqualToString:FT_AUTO_TRACK_OP_CLICK]&&[view isKindOfClass:UIView.class]) {
                NSString *vtp =[view ft_getParentsView];
                [content setValue:vtp forKey:FT_AUTO_TRACK_VTP_TREE_PATH];
            }
        }
        [content setValue:op forKey:FT_KEY_EVENT];
        NSDictionary *tag =@{FT_KEY_OPERATIONNAME:[NSString stringWithFormat:@"%@/%@",op,FT_KEY_EVENT]};
        [agent loggingWithType:FTAddDataNormal status:FTStatusInfo content:[FTJSONUtil ft_convertToJsonData:content] tags:tag field:nil tm:[[NSDate date] ft_dateTimestamp]];
        
    } @catch (NSException *exception) {
        ZYErrorLog(@" error: %@", exception);
    }
}
-(void)dealloc{
    [self.aspectTokenAry enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<ZY_AspectToken> token = obj;
        [token remove];
    }];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
