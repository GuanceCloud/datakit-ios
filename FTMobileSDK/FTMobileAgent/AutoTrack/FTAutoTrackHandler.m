//
//  FTTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/11/27.
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
@interface RUMView:NSObject
@property (nonatomic, copy) NSString *viewName;
@property (nonatomic, copy) NSString *identify;
@property (nonatomic, strong) NSNumber *loadTime;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, assign) BOOL isUntrackedModal;
- (instancetype)initWithViewController:(UIViewController *)viewController identify:(NSString *)identify;
- (void)updateViewControllerUUID;
- (NSString *)viewControllerUUID;
@end
@implementation RUMView
-(instancetype)initWithViewController:(UIViewController *)viewController identify:(NSString *)identify{
    self = [super init];
    if(self){
        _viewName = viewController.ft_viewControllerName;
        _identify = identify;
        _isUntrackedModal = NO;
        _viewController = viewController;
        NSNumber *loadTime = @0;
        if(viewController.ft_viewLoadStartTime){
            loadTime = [viewController.ft_viewLoadStartTime ft_nanosecondTimeIntervalToDate:[NSDate date]];
            viewController.ft_loadDuration = loadTime;
            viewController.ft_viewLoadStartTime = nil;
        }else{
            viewController.ft_loadDuration = loadTime;
        }
        _loadTime = loadTime;
    }
    return self;
}
- (NSString *)viewControllerUUID{
    return self.viewController.ft_viewUUID;
}
- (void)updateViewControllerUUID{
    _viewController.ft_viewUUID = [FTBaseInfoHandler randomUUID];
    _loadTime = @0;
}
@end
@interface FTAutoTrackHandler()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) NSMutableArray<RUMView*> *stack;
@property (nonatomic, assign) BOOL autoTrackView;
@property (nonatomic, assign) BOOL autoTrackAction;

@end
@implementation FTAutoTrackHandler
-(instancetype)init{
    self = [super init];
    if(self){
        _stack = [NSMutableArray new];
    }
    return self;
}
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    static FTAutoTrackHandler *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
-(void)startWithTrackView:(BOOL)trackView action:(BOOL)trackAction{
    _autoTrackView = trackView;
    _autoTrackAction = trackAction;
    if (trackView) {
        self.viewControllerHandler = self;
        [self logViewControllerLifeCycle];
    }else{
        self.viewControllerHandler = nil;
    }
    if (trackAction) {
        [self logTargetAction];
    }
    [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
}
- (void)logViewControllerLifeCycle{
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSError *error = NULL;
            [UIViewController ft_swizzleMethod:@selector(viewDidLoad) withMethod:@selector(ft_viewDidLoad) error:&error];
            [UIViewController ft_swizzleMethod:@selector(viewDidAppear:) withMethod:@selector(ft_viewDidAppear:) error:&error];
            [UIViewController ft_swizzleMethod:@selector(viewDidDisappear:) withMethod:@selector(ft_viewDidDisappear:) error:&error];
        });
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }
}
- (void)logTargetAction{
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
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
        [current updateViewControllerUUID];
        [self.addRumDatasDelegate startViewWithViewID:current.viewControllerUUID viewName:current.viewName property:nil];
    }
}
#pragma mark ========== FTUIViewControllerHandler ==========
-(void)notify_viewDidAppear:(UIViewController *)viewController animated:(BOOL)animated{
    NSString *identify = [NSString stringWithFormat:@"%p", viewController];
    if([self shouldTrackViewController:viewController]){
        RUMView *view = [[RUMView alloc]initWithViewController:viewController identify:identify];
        [self addView:view];
    }else if (@available(iOS 13.0,tvOS 13.0, *)){
        if(viewController.isModalInPresentation){
            RUMView *view = [[RUMView alloc]initWithViewController:viewController identify:identify];
            view.isUntrackedModal = YES;
            [self addView:view];
        }
    }
}
-(void)notify_viewDidDisappear:(UIViewController *)viewController animated:(BOOL)animated{
    [self removeView:viewController];
}
- (void)addView:(RUMView *)view{
    if([[self.stack lastObject].identify isEqualToString:view.identify]){
        return;
    }
    if ([self.stack lastObject]) {
        // 没有从数组中移除的原因是有一些特殊视图，比如模态视图添加到 window 时，或者新的 window 添加到窗口，window 上有 VC，原有的 VC 并不会调用 didDisappear 方法，当这些特殊视图移除时，原有的 VC 也不会调用 DidAppear 方法，所以需要保留，重新添加到 RUM View。
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
        [reStartView updateViewControllerUUID];
        [self startView:reStartView];
    }
}
- (void)startView:(RUMView *)view{
    if(!self.addRumDatasDelegate){
        return;
    }
    // 确保黑名单视图,不会影响采集视图的 duration
    // 黑名单视图模态弹出时，关闭上一个采集的 View，关闭时，重新开启上一个 View 采集
    if(!view.isUntrackedModal){
        [self.addRumDatasDelegate onCreateView:view.viewName loadTime:view.loadTime];
        [self.addRumDatasDelegate startViewWithViewID:view.viewControllerUUID viewName:view.viewName property:nil];
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
- (BOOL)shouldTrackViewController:(UIViewController *)viewController{
    return ![viewController isBlackListContainsViewController];
}
-(void)shutDown{
    self.stack = nil;
    self.addRumDatasDelegate = nil;
    self.viewControllerHandler = nil;
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    onceToken = 0;
}
@end
