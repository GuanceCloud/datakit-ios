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
-(instancetype)initWithViewController:(UIViewController *)viewController;
- (void)updateIdentify;
@end
@implementation RUMView
-(instancetype)initWithViewController:(UIViewController *)viewController{
    self = [super init];
    if(self){
        _viewName = viewController.ft_viewControllerName;
        _identify = viewController.ft_viewUUID;
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
- (void)updateIdentify{
    _identify = [FTBaseInfoHandler randomUUID];
    _viewController.ft_viewUUID = _identify;
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
            [UITableView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(ft_setDelegate:) error:&error];
            [UICollectionView ft_swizzleMethod:@selector(setDelegate:) withMethod:@selector(ft_setDelegate:) error:&error];
            [UIApplication ft_swizzleMethod:@selector(sendAction:to:from:forEvent:) withMethod:@selector(ft_sendAction:to:from:forEvent:) error:&error];
            [UITapGestureRecognizer ft_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(ft_initWithTarget:action:) error:&error];
            [UILongPressGestureRecognizer ft_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(ft_initWithTarget:action:) error:&error];
            [UITapGestureRecognizer ft_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(ft_addTarget:action:) error:&error];
            [UILongPressGestureRecognizer ft_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(ft_addTarget:action:) error:&error];
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
        [self.addRumDatasDelegate stopViewWithViewID:current.identify property:nil];
    }
}
-(void)applicationWillEnterForeground{
    if(!self.autoTrackView){
        return;
    }
    RUMView *current = [self.stack lastObject];
    if(current){
        [current updateIdentify];
        [self.addRumDatasDelegate startViewWithViewID:current.identify viewName:current.viewName property:nil];
    }
}
#pragma mark ========== FTUIViewControllerHandler ==========
-(void)notify_viewDidAppear:(UIViewController *)viewController animated:(BOOL)animated{
    if(![self shouldTrackViewController:viewController]){
        return;
    }
    viewController.ft_viewUUID = [FTBaseInfoHandler randomUUID];
    RUMView *view = [[RUMView alloc]initWithViewController:viewController];
    [self addView:view];
}
-(void)notify_viewDidDisappear:(UIViewController *)viewController animated:(BOOL)animated{
    if(![self shouldTrackViewController:viewController]){
        return;
    }
    [self removeView:viewController.ft_viewUUID];
}
- (void)addView:(RUMView *)view{
    if([[self.stack lastObject].identify isEqualToString:view.identify]){
        return;
    }
    if ([self.stack lastObject]) {
        // 没有从数组中移除的原因是有一些特殊视图，比如模态视图添加到window时，原有的 VC 并不会调用 didDisappear 方法，当这些特殊视图移除时，原有的 VC 也不会调用 DidAppear 方法，所以需要保留，重新添加到 RUM View。
        RUMView *current = [self.stack lastObject];
        [self.addRumDatasDelegate stopViewWithViewID:current.identify property:nil];
    }
    [self.addRumDatasDelegate onCreateView:view.viewName loadTime:view.loadTime];
    [self.addRumDatasDelegate startViewWithViewID:view.identify viewName:view.viewName property:nil];
    
    [self.stack enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(RUMView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([obj.identify isEqualToString:view.identify]){
            [self.stack removeObjectAtIndex:idx];
        }
    }];
    [self.stack addObject:view];
}
- (void)removeView:(NSString *)identify{
    if(![[self.stack lastObject].identify isEqualToString:identify]){
        [self.stack enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(RUMView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if([obj.identify isEqualToString:identify]){
                [self.stack removeObjectAtIndex:idx];
            }
        }];
        return;
    }
    [self.stack removeLastObject];
    [self.addRumDatasDelegate stopViewWithViewID:identify property:nil];
    
    if([self.stack lastObject]){
        RUMView *current = [self.stack lastObject];
        [current updateIdentify];
        [self.addRumDatasDelegate startViewWithViewID:current.identify viewName:current.viewName property:nil];
    }
}
- (BOOL)shouldTrackViewController:(UIViewController *)viewController{
    if([viewController isBlackListContainsViewController]){
        return NO;
    }
    UIViewController *parent = viewController.parentViewController;
    while (parent != nil) {
        if ([parent isKindOfClass:UIPageViewController.class] || [parent isKindOfClass:UISplitViewController.class]) {
            return NO;
        }else{
            parent = parent.parentViewController;
        }
    }
    return YES;
}
-(void)shutDown{
    self.stack = nil;
    self.addRumDatasDelegate = nil;
    self.viewControllerHandler = nil;
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
    onceToken = 0;
}
@end
