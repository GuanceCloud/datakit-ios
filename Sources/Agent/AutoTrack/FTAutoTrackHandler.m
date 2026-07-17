//
//  FTTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/11/27.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <TargetConditionals.h>
#import "FTAutoTrackHandler.h"

#if TARGET_OS_OSX
#import "Mac/FTAutoTrack.h"

@interface FTAutoTrackHandler ()
@property (nonatomic, weak, nullable) id<FTRumDatasProtocol> addRumDatasDelegate;
@end

@implementation FTAutoTrackHandler
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static FTAutoTrackHandler *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)startWithTrackView:(BOOL)trackView
                    action:(BOOL)trackAction
       addRumDatasDelegate:(id<FTRumDatasProtocol>)delegate {
    self.addRumDatasDelegate = delegate;
    [FTAutoTrack sharedInstance].addRumDatasDelegate = delegate;
    [[FTAutoTrack sharedInstance] startHookView:trackView action:trackAction];
}

- (void)shutDown {
    self.addRumDatasDelegate = nil;
    [FTAutoTrack sharedInstance].addRumDatasDelegate = nil;
}
@end

#else
#import "UIViewController+FTAutoTrack.h"
#import "FTInnerLog.h"
#import "FTSwizzle.h"
#import "FTSwizzler.h"
#import "UIApplication+FTAutoTrack.h"
#import "UIGestureRecognizer+FTAutoTrack.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
#import "FTAppLifeCycle.h"
#import "FTThreadDispatchManager.h"
#import "FTConstants.h"
#import "UIView+FTAutoTrack.h"
#import "FTAppLaunchTracker.h"
#import "FTDefaultUIKitViewTrackingHandler.h"
#import "FTDefaultActionTrackingHandler.h"
#import "FTAutoTrackActionPublisher.h"

#if TARGET_OS_IOS || TARGET_OS_TV
#define FT_HAS_SWIFTUI_VIEW_TRACKING 1
#else
#define FT_HAS_SWIFTUI_VIEW_TRACKING 0
#endif

#if TARGET_OS_IOS
#define FT_HAS_SWIFTUI_ACTION_TRACKING 1
#else
#define FT_HAS_SWIFTUI_ACTION_TRACKING 0
#endif

#if FT_HAS_SWIFTUI_VIEW_TRACKING
static BOOL FTViewControllerIsFromSwiftUIBundle(UIViewController *viewController) {
    NSBundle *bundle = [NSBundle bundleForClass:viewController.class];
    return [bundle.bundleURL.lastPathComponent isEqualToString:@"SwiftUI.framework"];
}
#else
static BOOL FTViewControllerIsFromSwiftUIBundle(UIViewController *viewController) {
    return NO;
}
#endif

#if FT_HAS_SWIFTUI_VIEW_TRACKING
API_AVAILABLE(ios(13.0), tvos(13.0))
@interface FTSwiftUIViewNameExtractor : NSObject
- (nullable NSString *)extractNameFromViewController:(UIViewController *)viewController;
@end

@protocol FTSwiftUIRUMViewHandling <NSObject>
- (void)notifyOnAppearWithIdentity:(NSString *)identity name:(NSString *)name property:(nullable NSDictionary *)property loadTime:(NSNumber *)loadTime;
- (void)notifyOnDisappearWithIdentity:(NSString *)identity;
@end

@interface FTSwiftUIRUMViewBridge : NSObject
@property (class, nonatomic, weak, nullable) id<FTSwiftUIRUMViewHandling> handler;
@end
#endif

#if FT_HAS_SWIFTUI_ACTION_TRACKING
@protocol FTSwiftUIRUMActionHandling <NSObject>
- (void)notifySwiftUITapActionWithName:(NSString *)name property:(nullable NSDictionary *)property;
@end

@interface FTSwiftUIRUMActionBridge : NSObject
@property (class, nonatomic, weak, nullable) id<FTSwiftUIRUMActionHandling> handler;
@end
#endif

@interface RUMView:NSObject
@property (nonatomic, copy) NSString *viewName;
@property (nonatomic, copy) NSString *identify;
@property (nonatomic, strong) NSNumber *loadTime;
@property (nonatomic, weak, nullable) UIViewController *viewController;
@property (nonatomic, assign) BOOL isUntrackedModal;
@property (nonatomic, copy) NSDictionary *property;
@property (nonatomic, copy) NSString *viewControllerUUID;

- (instancetype)initWithViewController:(UIViewController *)viewController identify:(NSString *)identify;
- (instancetype)initWithViewName:(NSString *)viewName identify:(NSString *)identify property:(nullable NSDictionary *)property loadTime:(NSNumber *)loadTime;
- (void)resetView;
@end
@implementation RUMView
-(instancetype)initWithViewController:(UIViewController *)viewController identify:(NSString *)identify{
    self = [super init];
    if(self){
        _viewName = [viewController.ft_viewControllerName copy];
        _identify = [identify copy];
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
- (instancetype)initWithViewName:(NSString *)viewName identify:(NSString *)identify property:(NSDictionary *)property loadTime:(NSNumber *)loadTime{
    self = [super init];
    if(self){
        _viewName = [viewName copy];
        _identify = [identify copy];
        _isUntrackedModal = NO;
        _property = [property copy];
        _viewControllerUUID = [FTBaseInfoHandler randomUUID];
        _loadTime = loadTime ?: @0;
    }
    return self;
}
- (void)resetView{
    _viewControllerUUID = [FTBaseInfoHandler randomUUID];
    _loadTime = @0;
}
@end
@interface FTAutoTrackHandler()<FTAppLifeCycleDelegate,FTUIViewControllerHandler,FTUIEventHandler,FTAppLaunchDataDelegate
#if FT_HAS_SWIFTUI_VIEW_TRACKING
,FTSwiftUIRUMViewHandling
#endif
#if FT_HAS_SWIFTUI_ACTION_TRACKING
,FTSwiftUIRUMActionHandling
#endif
>
@property (nonatomic, strong) NSMutableArray<RUMView*> *stack;
@property (nonatomic, assign) BOOL autoTrackView;
@property (nonatomic, assign) BOOL autoTrackAction;
@property (nonatomic, strong) FTAppLaunchTracker *launchTracker;
/// Pass event object, pass collected view and action data to RUM
@property (nonatomic, weak, nullable) id<FTRumDatasProtocol> addRumDatasDelegate;
@property (nonatomic, strong, nullable) FTViewTrackingHandler uiKitViewTrackingHandler;
@property (nonatomic, strong, nullable) id<FTSwiftUIViewTrackingHandler> swiftUIViewTrackingHandler;
#if FT_HAS_SWIFTUI_VIEW_TRACKING
@property (nonatomic, strong, nullable) FTSwiftUIViewNameExtractor *swiftUIViewNameExtractor API_AVAILABLE(ios(13.0), tvos(13.0));
#endif

@property (nonatomic, strong, nullable) FTActionTrackingHandler actionTrackingHandler;
@property (nonatomic, strong, nullable) FTAutoTrackActionPublisher *actionPublisher;
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
       swiftUIViewHandler:(id<FTSwiftUIViewTrackingHandler>)swiftUIViewHandler
            actionHandler:(FTActionTrackingHandler)actionHandler
           displayMonitor:(FTDisplayRateMonitor *)displayMonitor{
    [self startWithTrackView:trackView
                      action:trackAction
         addRumDatasDelegate:delegate
                 viewHandler:viewHandler
          swiftUIViewHandler:swiftUIViewHandler
               actionHandler:actionHandler
              displayMonitor:displayMonitor
   heatmapIdentifierRegistry:nil];
}

-(void)startWithTrackView:(BOOL)trackView
                   action:(BOOL)trackAction
      addRumDatasDelegate:(id<FTRumDatasProtocol>)delegate
              viewHandler:(FTViewTrackingHandler)viewHandler
       swiftUIViewHandler:(id<FTSwiftUIViewTrackingHandler>)swiftUIViewHandler
            actionHandler:(FTActionTrackingHandler)actionHandler
           displayMonitor:(FTDisplayRateMonitor *)displayMonitor
heatmapIdentifierRegistry:(id<FTHeatmapIdentifierRegistry>)heatmapIdentifierRegistry{
    _autoTrackView = trackView;
    _autoTrackAction = trackAction;
    _stack = [NSMutableArray new];
    _addRumDatasDelegate = delegate;
    self.actionTrackingHandler = actionHandler ? actionHandler : [FTDefaultActionTrackingHandler new];
    FTAutoTrackHeatmapResolver *heatmapResolver = [[FTAutoTrackHeatmapResolver alloc]initWithRegistry:heatmapIdentifierRegistry];
    self.actionPublisher = [[FTAutoTrackActionPublisher alloc]initWithActionTrackingHandler:self.actionTrackingHandler addRumDatasDelegate:delegate heatmapResolver:heatmapResolver];
#if FT_HAS_SWIFTUI_VIEW_TRACKING
    [self bindSwiftUIRUMViewBridgeIfAvailable];
#endif
#if FT_HAS_SWIFTUI_ACTION_TRACKING
    [self bindSwiftUIRUMActionBridgeIfAvailable];
#endif
    if (trackView) {
        self.viewControllerHandler = self;
        [self hookViewControllerLifeCycle];
        self.uiKitViewTrackingHandler = viewHandler ? viewHandler : [FTDefaultUIKitViewTrackingHandler new];
        self.swiftUIViewTrackingHandler = swiftUIViewHandler;
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }else{
        self.viewControllerHandler = nil;
        self.uiKitViewTrackingHandler = nil;
        self.swiftUIViewTrackingHandler = nil;
#if FT_HAS_SWIFTUI_VIEW_TRACKING
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            self.swiftUIViewNameExtractor = nil;
        }
#endif
    }
    if (trackAction) {
        self.actionHandler = self;
        [self hookTargetAction];
        self.launchTracker = [[FTAppLaunchTracker alloc]initWithDelegate:self displayMonitor:displayMonitor];
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
            [UIApplication ft_swizzleMethod:@selector(sendEvent:) withMethod:@selector(ft_sendEvent:) error:&error];
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
-(void)ftAppColdStart:(NSDate *)launchTime duration:(NSNumber *)duration isPreWarming:(BOOL)isPreWarming fields:(NSDictionary *)fields{
    if (self.actionTrackingHandler && [self.actionTrackingHandler respondsToSelector:@selector(rumLaunchActionWithLaunchType:)]) {
        FTRUMAction *action = [self.actionTrackingHandler rumLaunchActionWithLaunchType:isPreWarming?FTLaunchWarm:FTLaunchCold];
        action.property = fields;
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
- (void)notify_sendAction:(UIView *)view heatmapTargetView:(UIView *)heatmapTargetView locationResolver:(FTHeatmapLocationResolver)locationResolver {
#if TARGET_OS_IOS
    [self.actionPublisher publishUIKitActionWithTargetView:view heatmapTargetView:heatmapTargetView locationResolver:locationResolver];
#endif
}

#if FT_HAS_SWIFTUI_ACTION_TRACKING
- (void)notify_swiftUIActionWithName:(NSString *)actionName property:(NSDictionary *)property{
    [self.actionPublisher publishSwiftUIActionWithName:actionName property:property];
}
#endif

- (void)notify_sendActionWithPressType:(UIPressType)type view:(nonnull UIView *)view {
#if TARGET_OS_TV
    [self.actionPublisher publishTVActionWithPressType:type view:view];
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
    NSString *identify = [NSString stringWithFormat:@"%p", viewController];
    for (RUMView *view in self.stack) {
        if ([view.identify isEqualToString:identify]) {
            [self addView:view];
            return;
        }
    }

    if (!FTViewControllerIsFromSwiftUIBundle(viewController) &&
        self.uiKitViewTrackingHandler &&
        [self.uiKitViewTrackingHandler respondsToSelector:@selector(rumViewForViewController:)]) {
        FTRUMView *rumView = [self.uiKitViewTrackingHandler rumViewForViewController:viewController];
        if (rumView) {
            RUMView *view = [[RUMView alloc]initWithViewController:viewController identify:identify];
            view.viewName = rumView.viewName;
            view.property = rumView.property;
            view.isUntrackedModal = rumView.isUntrackedModal;
            [self addView:view];
            return;
        }
    }
#if FT_HAS_SWIFTUI_VIEW_TRACKING
    if (FTViewControllerIsFromSwiftUIBundle(viewController) &&
        self.swiftUIViewTrackingHandler &&
        [self.swiftUIViewTrackingHandler respondsToSelector:@selector(rumViewForExtractedViewName:)]) {
        NSString *extractedViewName = [self extractSwiftUIViewNameFromViewController:viewController];
        if (extractedViewName.length == 0) {
            return;
        }

        FTRUMView *rumView = [self.swiftUIViewTrackingHandler rumViewForExtractedViewName:extractedViewName];
        if (rumView) {
            RUMView *view = [[RUMView alloc]initWithViewController:viewController identify:identify];
            view.viewName = rumView.viewName;
            view.property = rumView.property;
            view.isUntrackedModal = rumView.isUntrackedModal;
            [self addView:view];
        }
    }
#endif
}
-(void)notify_viewDidDisappear:(UIViewController *)viewController animated:(BOOL)animated{
    [self removeView:viewController];
}
#if FT_HAS_SWIFTUI_VIEW_TRACKING
#pragma mark ========== FTSwiftUIRUMViewHandling ==========
- (void)notifyOnAppearWithIdentity:(NSString *)identity name:(NSString *)name property:(NSDictionary *)property loadTime:(NSNumber *)loadTime{
    if (identity.length == 0 || name.length == 0) {
        return;
    }
    for (RUMView *view in self.stack) {
        if ([view.identify isEqualToString:identity]) {
            [self addView:view];
            return;
        }
    }

    RUMView *view = [[RUMView alloc]initWithViewName:name identify:identity property:property loadTime:loadTime];
    [self addView:view];
}

- (void)notifyOnDisappearWithIdentity:(NSString *)identity{
    if (identity.length == 0) {
        return;
    }
    [self removeViewWithIdentity:identity];
}
#endif

#if FT_HAS_SWIFTUI_ACTION_TRACKING
#pragma mark ========== FTSwiftUIRUMActionHandling ==========
- (void)notifySwiftUITapActionWithName:(NSString *)name property:(NSDictionary *)property{
    [self notify_swiftUIActionWithName:name property:property];
}
#endif

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
    [self removeViewWithIdentity:identify];
}
- (void)removeViewWithIdentity:(NSString *)identify{
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
    self.swiftUIViewTrackingHandler = nil;
#if FT_HAS_SWIFTUI_VIEW_TRACKING
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        self.swiftUIViewNameExtractor = nil;
    }
    [self unbindSwiftUIRUMViewBridgeIfNeeded];
#endif
#if FT_HAS_SWIFTUI_ACTION_TRACKING
    [self unbindSwiftUIRUMActionBridgeIfNeeded];
#endif
    self.actionTrackingHandler = nil;
    self.actionPublisher = nil;
    self.autoTrackView = NO;
    self.autoTrackAction = NO;

    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}

#if FT_HAS_SWIFTUI_VIEW_TRACKING
- (void)bindSwiftUIRUMViewBridgeIfAvailable{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        FTSwiftUIRUMViewBridge.handler = self;
    }
}

- (void)unbindSwiftUIRUMViewBridgeIfNeeded{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        if (FTSwiftUIRUMViewBridge.handler == self) {
            FTSwiftUIRUMViewBridge.handler = nil;
        }
    }
}
#endif

#if FT_HAS_SWIFTUI_ACTION_TRACKING
- (void)bindSwiftUIRUMActionBridgeIfAvailable{
    if (@available(iOS 13.0, *)) {
        FTSwiftUIRUMActionBridge.handler = self;
    }
}

- (void)unbindSwiftUIRUMActionBridgeIfNeeded{
    if (@available(iOS 13.0, *)) {
        if (FTSwiftUIRUMActionBridge.handler == self) {
            FTSwiftUIRUMActionBridge.handler = nil;
        }
    }
}
#endif

#if FT_HAS_SWIFTUI_VIEW_TRACKING
- (nullable NSString *)extractSwiftUIViewNameFromViewController:(UIViewController *)viewController{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        return [self.swiftUIViewNameExtractor extractNameFromViewController:viewController];
    }
    return nil;
}

- (FTSwiftUIViewNameExtractor *)swiftUIViewNameExtractor API_AVAILABLE(ios(13.0), tvos(13.0)){
    if (!_swiftUIViewNameExtractor) {
        _swiftUIViewNameExtractor = [FTSwiftUIViewNameExtractor new];
    }
    return _swiftUIViewNameExtractor;
}
#endif
@end
#endif
