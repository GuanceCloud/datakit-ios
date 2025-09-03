//
//  FTTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/11/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTAutoTrackHandler.h"
#import "UIViewController+FTAutoTrack.h"
#import "FTLog+Private.h"
#import "FTSwizzle.h"
#import "UIApplication+FTAutoTrack.h"
#import "UIGestureRecognizer+FTAutoTrack.h"
#import "UIScrollView+FTAutoTrack.h"
#import "BlacklistedVCClassNames.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
#import "FTAppLifeCycle.h"
#import "FTThreadDispatchManager.h"
#import "FTConstants.h"
#import "UIView+FTAutoTrack.h"
#import "FTAppLaunchTracker.h"
#import "FTDefaultUIKitViewTrackingHandler.h"
#import "FTDefaultActionTrackingHandler.h"
@interface RUMView:NSObject
@property (nonatomic, copy) NSString *viewName;
@property (nonatomic, copy) NSString *identify;
@property (nonatomic, strong) NSNumber *loadTime;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, assign) BOOL isUntrackedModal;
@property (nonatomic, copy) NSDictionary *property;
@property (nonatomic, copy) NSString *viewControllerUUID;

- (instancetype)initWithViewController:(UIViewController *)viewController identify:(NSString *)identify;
- (void)resetView;
@end
@implementation RUMView
-(instancetype)initWithViewController:(UIViewController *)viewController identify:(NSString *)identify{
    self = [super init];
    if(self){
        _viewName = viewController.ft_viewControllerName;
        _identify = identify;
        _isUntrackedModal = NO;
        _viewController = viewController;
        _viewControllerUUID = [FTBaseInfoHandler randomUUID];
        _loadTime = @0;
        if(viewController.ft_loadDuration != nil){
            _loadTime = viewController.ft_loadDuration;
            viewController.ft_loadDuration = nil;
        }
    }
    return self;
}
- (void)resetView{
    _viewControllerUUID = [FTBaseInfoHandler randomUUID];
    _loadTime = @0;
}
@end
@interface FTAutoTrackHandler()<FTAppLifeCycleDelegate,FTUIViewControllerHandler,FTUIEventHandler,FTAppLaunchDataDelegate>
@property (nonatomic, strong) NSMutableArray<RUMView*> *stack;
@property (nonatomic, assign) BOOL autoTrackView;
@property (nonatomic, assign) BOOL autoTrackAction;
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
/// Pass event object, pass collected view and action data to RUM
@property (nonatomic, weak) id<FTRumDatasProtocol> addRumDatasDelegate;
@property (nonatomic, strong, nullable) FTViewTrackingHandler uiKitViewTrackingHandler;
@property (nonatomic, strong, nullable) FTActionTrackingHandler actionTrackingHandler;
@end
@implementation FTAutoTrackHandler
-(instancetype)init{
    self = [super init];
    if(self){
        _stack = [NSMutableArray new];
    }
    return self;
}
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static FTAutoTrackHandler *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
-(void)startWithTrackView:(BOOL)trackView
                   action:(BOOL)trackAction
      addRumDatasDelegate:(id<FTRumDatasProtocol>)delegate
              viewHandler:(FTViewTrackingHandler)viewHandler
            actionHandler:(FTActionTrackingHandler)actionHandler{
    _autoTrackView = trackView;
    _autoTrackAction = trackAction;
    _stack = [NSMutableArray new];
    _addRumDatasDelegate = delegate;
    if (trackView) {
        self.viewControllerHandler = self;
        [self hookViewControllerLifeCycle];
        self.uiKitViewTrackingHandler = viewHandler ? viewHandler : [FTDefaultUIKitViewTrackingHandler new];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }else{
        self.viewControllerHandler = nil;
    }
    if (trackAction) {
        self.actionHandler = self;
        [self hookTargetAction];
        self.actionTrackingHandler = actionHandler ? actionHandler : [FTDefaultActionTrackingHandler new];
        self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self];
    }
}
- (void)hookViewControllerLifeCycle{
    @try {
        static dispatch_once_t viewOnceToken;
        dispatch_once(&viewOnceToken, ^{
            NSError *error = NULL;
            [UIViewController ft_swizzleMethod:@selector(viewDidLoad) withMethod:@selector(ft_viewDidLoad) error:&error];
            [UIViewController ft_swizzleMethod:@selector(viewDidAppear:) withMethod:@selector(ft_viewDidAppear:) error:&error];
            [UIViewController ft_swizzleMethod:@selector(viewDidDisappear:) withMethod:@selector(ft_viewDidDisappear:) error:&error];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }
}
- (void)hookTargetAction{
    @try {
        static dispatch_once_t actionOnceToken;
        dispatch_once(&actionOnceToken, ^{
            NSError *error = NULL;
#if TARGET_OS_IOS
            [UITableView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(ft_setDelegate:) error:&error];
            [UICollectionView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(ft_setDelegate:) error:&error];
            [UIApplication ft_swizzleMethod:@selector(sendAction:to:from:forEvent:) withMethod:@selector(ft_sendAction:to:from:forEvent:) error:&error];
            [UITapGestureRecognizer ft_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(ft_initWithTarget:action:) error:&error];
            [UILongPressGestureRecognizer ft_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(ft_initWithTarget:action:) error:&error];
            [UITapGestureRecognizer ft_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(ft_addTarget:action:) error:&error];
            [UILongPressGestureRecognizer ft_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(ft_addTarget:action:) error:&error];
#elif TARGET_OS_TV
            [UIApplication ft_swizzleMethod:@selector(sendEvent:) withMethod:@selector(ft_sendEvent:) error:&error];
#endif
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    
}
#pragma mark ========== RUM-Action: App Launch ==========
-(void)ftAppHotStart:(NSDate *)launchTime duration:(NSNumber *)duration{
    if (self.actionTrackingHandler && [self.actionTrackingHandler respondsToSelector:@selector(rumLaunchActionWithLaunchType:)]) {
        FTRUMAction *action = [self.actionTrackingHandler rumLaunchActionWithLaunchType:FTLaunchHot];
        if (action == nil) {
            return;
        }
        if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(addLaunch:type:launchTime:duration:property:)]) {
            [self.addRumDatasDelegate addLaunch:action.actionName type:FT_LAUNCH_HOT launchTime:launchTime duration:duration property:action.property];
        }
    }
}
-(void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming{
    if (self.actionTrackingHandler && [self.actionTrackingHandler respondsToSelector:@selector(rumLaunchActionWithLaunchType:)]) {
        FTRUMAction *action = [self.actionTrackingHandler rumLaunchActionWithLaunchType:isPreWarming?FTLaunchWarm:FTLaunchCold];
        if (action == nil) {
            return;
        }
        if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(addLaunch:type:launchTime:duration:property:)]) {
            NSString *actionType = isPreWarming?FT_LAUNCH_WARM:FT_LAUNCH_COLD;
            [self.addRumDatasDelegate addLaunch:action.actionName type:actionType launchTime:launchTime duration:duration property:action.property];
        }
    }
}
#pragma mark ========== FTUIEventHandler ==========
- (void)notify_sendAction:(UIView *)view{
#if TARGET_OS_IOS
    if (self.actionTrackingHandler && [self.actionTrackingHandler respondsToSelector:@selector(rumActionWithTargetView:)]) {
        FTRUMAction *action = [self.actionTrackingHandler rumActionWithTargetView:view];
        if ( action == nil ) return;
        if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]) {
            [self.addRumDatasDelegate startAction:action.actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:action.property];
        }
    }
#endif
}

- (void)notify_sendActionWithPressType:(UIPressType)type view:(nonnull UIView *)view {
#if TARGET_OS_TV
    if (self.actionTrackingHandler && [self.actionTrackingHandler respondsToSelector:@selector(rumActionWithPressType:targetView:)]) {
        FTRUMAction *action = [self.actionTrackingHandler rumActionWithPressType:type targetView:view];
        if ( action == nil ) return;
        if (self.addRumDatasDelegate && [self.addRumDatasDelegate respondsToSelector:@selector(startAction:actionType:property:)]) {
            [self.addRumDatasDelegate startAction:action.actionName actionType:FT_KEY_ACTION_TYPE_CLICK property:action.property];
        }
    }
#endif
}

#pragma mark ========== FTAppLifeCycleDelegate ==========
-(void)applicationDidEnterBackground{
    if(!self.autoTrackView){
        return;
    }
    RUMView *current = [self.stack lastObject];
    if(current){
        [self.addRumDatasDelegate stopViewWithViewID:current.viewControllerUUID property:nil];
    }
}
-(void)applicationWillEnterForeground{
    if(!self.autoTrackView){
        return;
    }
    RUMView *current = [self.stack lastObject];
    if(current){
        [current resetView];
        [self.addRumDatasDelegate startViewWithViewID:current.viewControllerUUID viewName:current.viewName property:nil];
    }
}
#pragma mark ========== FTUIViewControllerHandler ==========
-(void)notify_viewDidAppear:(UIViewController *)viewController animated:(BOOL)animated{
    // if User-defined 
    if (self.uiKitViewTrackingHandler && [self.uiKitViewTrackingHandler respondsToSelector:@selector(rumViewForViewController:)]) {
        FTRUMView *rumView = [self.uiKitViewTrackingHandler rumViewForViewController:viewController];
        if (rumView) {
            NSString *identify = [NSString stringWithFormat:@"%p", viewController];
            RUMView *view = [[RUMView alloc]initWithViewController:viewController identify:identify];
            view.viewName = rumView.viewName;
            view.property = rumView.property;
            view.isUntrackedModal = rumView.isUntrackedModal;
            [self addView:view];
        }
        return;
    }
}
-(void)notify_viewDidDisappear:(UIViewController *)viewController animated:(BOOL)animated{
    [self removeView:viewController];
}
- (void)addView:(RUMView *)view{
    // Ignore repeated startView events triggered by partially returning to the original page via side swipe
    if([[self.stack lastObject].identify isEqualToString:view.identify]){
        return;
    }
    if ([self.stack lastObject]) {
        // The reason for not removing from the array is that there are some special views, such as modal view transitions in non-fullscreen mode, or when a new window is added to the window hierarchy with a view controller on it. The original view controller will not call the didDisappear method, and when these special views are removed, the original view controller will not call the didAppear method either. Therefore, it needs to be retained and re-added to the RUM View.
        RUMView *current = [self.stack lastObject];
        [self stopView:current];
    }
    [self startView:view];
    
    [self.stack enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(RUMView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([obj.identify isEqualToString:view.identify]){
            [self.stack removeObjectAtIndex:idx];
        }
    }];
    [self.stack addObject:view];
}
- (void)removeView:(UIViewController *)viewController{
    NSString *identify = [NSString stringWithFormat:@"%p", viewController];
    if(![[self.stack lastObject].identify isEqualToString:identify]){
        [self.stack enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(RUMView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if([obj.identify isEqualToString:identify]){
                [self.stack removeObjectAtIndex:idx];
            }
        }];
        return;
    }
    RUMView *stopView = [self.stack lastObject];
    if(stopView){
        [self.stack removeLastObject];
        [self stopView:stopView];
    }
    
    RUMView *reStartView = [self.stack lastObject];
    if(reStartView){
        [reStartView resetView];
        [self startView:reStartView];
    }
}
- (void)startView:(RUMView *)view{
    if(!self.addRumDatasDelegate){
        return;
    }
    // Ensure that untracked modal views do not affect the duration of tracked views
    // When an untracked modal view pops up, close the last tracked View; when the modal view is closed, restart tracking the last View
    if(!view.isUntrackedModal){
        [self.addRumDatasDelegate onCreateView:view.viewName loadTime:view.loadTime];
        [self.addRumDatasDelegate startViewWithViewID:view.viewControllerUUID viewName:view.viewName property:view.property];
    }
}
- (void)stopView:(RUMView *)view{
    if(!self.addRumDatasDelegate){
        return;
    }
    if(!view.isUntrackedModal){
        [self.addRumDatasDelegate stopViewWithViewID:view.viewControllerUUID property:nil];
    }
}
-(void)shutDown{
    self.addRumDatasDelegate = nil;
    self.viewControllerHandler = nil;
    self.actionHandler = nil;
    self.uiKitViewTrackingHandler = nil;
    self.actionTrackingHandler = nil;
    self.autoTrackView = NO;
    self.autoTrackAction = NO;
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}
@end
