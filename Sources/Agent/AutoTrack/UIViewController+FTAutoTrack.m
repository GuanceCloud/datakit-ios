//
//  UIViewController+FT_RootVC.m
//  FTAutoTrack
//
//  Created by hulilei on 2019/12/2.
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

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_TV
#import "UIViewController+FTAutoTrack.h"
#import <objc/runtime.h>
#import "FTConstants.h"
#import "FTInnerLog.h"
#import "FTAutoTrackHandler.h"
#import "BlacklistedVCClassNames.h"
#import "FTDateUtil.h"
#import "FTSwizzler.h"
#import "FTViewControllerSwizzling.h"
#import <string.h>
#import <stdatomic.h>

@interface FTViewLoadingState : NSObject
@property (nonatomic, strong, nullable) NSNumber *loadDuration;
@property (nonatomic, assign) NSUInteger viewDidLoadDepth;
@property (nonatomic, assign) NSUInteger viewWillAppearDepth;
@property (nonatomic, assign) NSUInteger viewWillLayoutSubviewsDepth;
@property (nonatomic, assign) NSUInteger viewDidAppearDepth;
@property (nonatomic, assign) NSUInteger viewLoadGeneration;
@property (nonatomic, assign) NSUInteger viewLoadDurationGeneration;
@property (nonatomic, assign) uint64_t viewLoadStartTime;
@property (nonatomic, assign) uint64_t viewDidLoadDuration;
@property (nonatomic, assign) uint64_t firstViewWillAppearStartTime;
@property (nonatomic, assign) uint64_t firstViewWillLayoutSubviewsStartTime;
@property (nonatomic, assign) BOOL hasViewLoadStartTime;
@property (nonatomic, assign) BOOL hasViewDidLoadDuration;
@property (nonatomic, assign) BOOL hasFirstViewWillAppearStartTime;
@property (nonatomic, assign) BOOL hasFirstViewWillLayoutSubviewsStartTime;
@property (nonatomic, assign) BOOL hasViewLoadGeneration;
@property (nonatomic, assign) BOOL hasViewLoadDurationGeneration;
@property (nonatomic, assign) BOOL viewLoadDurationCalculated;
@property (nonatomic, assign) BOOL viewLoadDurationReported;
@property (nonatomic, assign) BOOL usesSwiftUIBaseLifecycleLoadingTime;
@end

@implementation FTViewLoadingState
@end

static const void *viewLoadingStateKey = &viewLoadingStateKey;
static const void *viewDidLoadSwizzleKey = &viewDidLoadSwizzleKey;
static const void *viewWillAppearSwizzleKey = &viewWillAppearSwizzleKey;
static const void *viewWillLayoutSubviewsSwizzleKey = &viewWillLayoutSubviewsSwizzleKey;
static const void *viewDidAppearSwizzleKey = &viewDidAppearSwizzleKey;
static const void *viewLoadDurationDisabledKey = &viewLoadDurationDisabledKey;
static const void *viewLoadDurationInstrumentedKey = &viewLoadDurationInstrumentedKey;
static atomic_uint_fast64_t viewLoadGeneration = ATOMIC_VAR_INIT(0);
static atomic_bool swiftUIViewLoadingTimeEnabled = ATOMIC_VAR_INIT(false);

static BOOL FTViewControllerClassIsBlacklisted(Class viewControllerClass) {
    @try {
        NSDictionary *blackList = [BlacklistedVCClassNames ft_blacklistedViewControllerClassNames][FT_BLACK_LIST_VIEW];
        for (NSString *className in blackList[@"public"]) {
            Class blacklistedClass = NSClassFromString(className);
            if (blacklistedClass != Nil && [viewControllerClass isSubclassOfClass:blacklistedClass]) {
                return YES;
            }
        }
        return [(NSArray *)blackList[@"private"] containsObject:NSStringFromClass(viewControllerClass)];
    } @catch (NSException *exception) {
        FTInnerLogError(@"error: %@", exception);
    }
    return NO;
}

static BOOL FTImagePathIsFromSystemLibrary(const char *imagePath) {
    return imagePath != NULL && strstr(imagePath, "/System/Library/") != NULL;
}

static BOOL FTViewControllerClassIsFromSystemImage(Class viewControllerClass) {
    return FTImagePathIsFromSystemLibrary(class_getImageName(viewControllerClass));
}

static BOOL FTViewControllerClassIsFromSwiftUIBundle(Class viewControllerClass) {
    NSBundle *bundle = [NSBundle bundleForClass:viewControllerClass];
    return [bundle.bundleURL.lastPathComponent isEqualToString:@"SwiftUI.framework"];
}

static BOOL FTViewControllerClassIsFromSwiftUIImage(Class viewControllerClass) {
    const char *imagePath = class_getImageName(viewControllerClass);
    return imagePath != NULL && strstr(imagePath, "/SwiftUI.framework/") != NULL;
}

@implementation UIViewController (FTAutoTrack)
+ (NSUInteger)ft_currentViewLoadGeneration{
    return (NSUInteger)atomic_load_explicit(&viewLoadGeneration, memory_order_relaxed);
}
+ (void)ft_invalidatePendingViewLoadDurations{
    atomic_fetch_add_explicit(&viewLoadGeneration, 1, memory_order_relaxed);
}
+ (void)ft_setSwiftUIViewLoadingTimeEnabled:(BOOL)enabled{
    atomic_store_explicit(&swiftUIViewLoadingTimeEnabled, enabled, memory_order_relaxed);
}
-(void)setFt_viewLoadStartTime:(NSNumber *)viewLoadStartTime{
    FTViewLoadingState *state = [self ft_viewLoadingStateCreateIfNeeded:viewLoadStartTime != nil];
    if (state == nil) {
        return;
    }
    state.hasViewLoadStartTime = viewLoadStartTime != nil;
    state.viewLoadStartTime = [viewLoadStartTime unsignedLongLongValue];
}
-(NSNumber *)ft_viewLoadStartTime{
    FTViewLoadingState *state = [self ft_viewLoadingStateCreateIfNeeded:NO];
    return state.hasViewLoadStartTime ? @(state.viewLoadStartTime) : nil;
}
-(NSNumber *)ft_loadDuration{
    return [self ft_viewLoadingStateCreateIfNeeded:NO].loadDuration;
}
-(void)setFt_loadDuration:(NSNumber *)ft_loadDuration{
    FTViewLoadingState *state = [self ft_viewLoadingStateCreateIfNeeded:ft_loadDuration != nil];
    if (state == nil) {
        return;
    }
    state.loadDuration = ft_loadDuration;
    if (ft_loadDuration == nil) {
        state.hasViewLoadDurationGeneration = NO;
    }
}

#pragma mark - UIViewController loading duration swizzling

+ (void)ft_swizzleLoadedCustomViewControllerClasses{
    [[FTViewControllerSwizzling sharedInstance] swizzleLoadedViewControllerClassesWithCompletion:nil];
}
+ (NSArray<NSString *> *)ft_loadingTimeCandidateClassNamesFromClassNames:(NSArray<NSString *> *)classNames{
    NSMutableArray<NSString *> *candidateClassNames = [NSMutableArray array];
    for (NSString *className in classNames) {
        // Keep class names across queues. objc_lookUpClass and superclass inspection do not create a
        // controller instance; lifecycle method replacement remains confined to the main thread.
        Class viewControllerClass = objc_lookUpClass(className.UTF8String);
        if ([self ft_isCustomViewControllerClass:viewControllerClass] && ![self ft_viewLoadingDurationDisabledForClass:viewControllerClass]) {
            [candidateClassNames addObject:className];
        }
    }
    return candidateClassNames;
}
+ (NSUInteger)ft_installViewControllerLifecycleSwizzlesForClassNames:(NSArray<NSString *> *)classNames{
    NSUInteger instrumentedClassCount = 0;
    for (NSString *className in classNames) {
        Class viewControllerClass = objc_lookUpClass(className.UTF8String);
        BOOL wasInstrumented = [self ft_viewLoadingDurationInstrumentedForClass:viewControllerClass];
        if (!wasInstrumented && [self ft_installViewControllerLifecycleSwizzlesForClass:viewControllerClass]) {
            instrumentedClassCount++;
        }
    }
    return instrumentedClassCount;
}
+ (BOOL)ft_installViewControllerLifecycleSwizzlesForClass:(Class)viewControllerClass{
    if (viewControllerClass == Nil || [self ft_viewLoadingDurationDisabledForClass:viewControllerClass]) {
        return NO;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self ft_installViewControllerLifecycleSwizzlesForClass:viewControllerClass];
        });
        return NO;
    }
    @try {
        FTSwizzlerInstanceMethod(viewControllerClass,
                                 @selector(viewDidLoad),
                                 FTSWReturnType(void),
                                 FTSWArguments(),
                                 FTSWReplacement({
            UIViewController *viewController = (UIViewController *)self;
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:YES];
            @try {
                [viewController ft_viewDidLoadWillStartWithState:state];
            } @catch (NSException *exception) {
                FTInnerLogError(@"viewDidLoad start record exception: %@", exception);
            }
            FTSWCallOriginal();
            @try {
                [viewController ft_viewDidLoadDidEndWithState:state];
            } @catch (NSException *exception) {
                FTInnerLogError(@"viewDidLoad end record exception: %@", exception);
            }
        }), FTSwizzlerModeOncePerClass, viewDidLoadSwizzleKey);
        FTSwizzlerInstanceMethod(viewControllerClass,
                                 @selector(viewWillAppear:),
                                 FTSWReturnType(void),
                                 FTSWArguments(BOOL animated),
                                 FTSWReplacement({
            UIViewController *viewController = (UIViewController *)self;
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:NO];
            if (state != nil && state.viewLoadDurationCalculated) {
                FTSWCallOriginal(animated);
                return;
            }
            @try {
                [viewController ft_viewWillAppearWillStartWithState:state];
            } @catch (NSException *exception) {
                FTInnerLogError(@"viewWillAppear start record exception: %@", exception);
            }
            FTSWCallOriginal(animated);
            @try {
                [viewController ft_viewWillAppearDidEndWithState:state];
            } @catch (NSException *exception) {
                FTInnerLogError(@"viewWillAppear end record exception: %@", exception);
            }
        }), FTSwizzlerModeOncePerClass, viewWillAppearSwizzleKey);
        FTSwizzlerInstanceMethod(viewControllerClass,
                                 @selector(viewWillLayoutSubviews),
                                 FTSWReturnType(void),
                                 FTSWArguments(),
                                 FTSWReplacement({
            UIViewController *viewController = (UIViewController *)self;
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:NO];
            if (state != nil && state.viewLoadDurationCalculated) {
                FTSWCallOriginal();
                return;
            }
            @try {
                [viewController ft_viewWillLayoutSubviewsWillStartWithState:state];
            } @catch (NSException *exception) {
                FTInnerLogError(@"viewWillLayoutSubviews start record exception: %@", exception);
            }
            FTSWCallOriginal();
            @try {
                [viewController ft_viewWillLayoutSubviewsDidEndWithState:state];
            } @catch (NSException *exception) {
                FTInnerLogError(@"viewWillLayoutSubviews end record exception: %@", exception);
            }
        }), FTSwizzlerModeOncePerClass, viewWillLayoutSubviewsSwizzleKey);
        FTSwizzlerInstanceMethod(viewControllerClass,
                                 @selector(viewDidAppear:),
                                 FTSWReturnType(void),
                                 FTSWArguments(BOOL animated),
                                 FTSWReplacement({
            UIViewController *viewController = (UIViewController *)self;
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:YES];
            BOOL isOutermostAppearance = state.viewDidAppearDepth == 0;
            uint64_t viewDidAppearStartTime = isOutermostAppearance && !state.viewLoadDurationCalculated ? FTDateUtil.systemTime : 0;
            state.viewDidAppearDepth++;
            FTSWCallOriginal(animated);
            if (state.viewDidAppearDepth > 0) {
                state.viewDidAppearDepth--;
            }
            if (isOutermostAppearance && state.viewDidAppearDepth == 0) {
                [viewController ft_completeViewLoadingDurationForState:state viewDidAppearStartTime:viewDidAppearStartTime];
                [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:viewController animated:animated];
            }
        }), FTSwizzlerModeOncePerClass, viewDidAppearSwizzleKey);
        objc_setAssociatedObject(viewControllerClass, viewLoadDurationInstrumentedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    } @catch (NSException *exception) {
        [self ft_disableViewLoadingDurationForClass:viewControllerClass exception:exception];
        return NO;
    }
}
+ (BOOL)ft_viewLoadingDurationInstrumentedForClass:(Class)viewControllerClass{
    return viewControllerClass != Nil && [objc_getAssociatedObject(viewControllerClass, viewLoadDurationInstrumentedKey) boolValue];
}
+ (BOOL)ft_isViewControllerSubclass:(Class)viewControllerClass{
    if (viewControllerClass == Nil || viewControllerClass == UIViewController.class) {
        return NO;
    }
    for (Class currentClass = class_getSuperclass(viewControllerClass); currentClass != Nil; currentClass = class_getSuperclass(currentClass)) {
        if (currentClass == UIViewController.class) {
            return YES;
        }
    }
    return NO;
}
+ (BOOL)ft_isCustomViewControllerClass:(Class)viewControllerClass{
    if (![self ft_isViewControllerSubclass:viewControllerClass] || class_getImageName(viewControllerClass) == NULL || FTViewControllerClassIsFromSystemImage(viewControllerClass)) {
        return NO;
    }
    return [self ft_shouldTrackDefaultViewControllerClass:viewControllerClass];
}
+ (BOOL)ft_shouldTrackDefaultViewControllerClass:(Class)viewControllerClass{
    return viewControllerClass != Nil && !FTViewControllerClassIsBlacklisted(viewControllerClass) && !FTViewControllerClassIsFromSwiftUIBundle(viewControllerClass);
}
+ (BOOL)ft_hasViewLoadingDurationInstrumentedClassInHierarchy:(Class)viewControllerClass{
    for (Class currentClass = viewControllerClass; currentClass != Nil && currentClass != UIViewController.class; currentClass = class_getSuperclass(currentClass)) {
        if ([objc_getAssociatedObject(currentClass, viewLoadDurationInstrumentedKey) boolValue]) {
            return YES;
        }
    }
    return NO;
}
+ (BOOL)ft_viewLoadingDurationDisabledForClass:(Class)viewControllerClass{
    if (viewControllerClass == nil) {
        return NO;
    }
    for (Class currentClass = viewControllerClass; currentClass != nil && currentClass != UIViewController.class; currentClass = class_getSuperclass(currentClass)) {
        if ([objc_getAssociatedObject(currentClass, viewLoadDurationDisabledKey) boolValue]) {
            return YES;
        }
    }
    return NO;
}
+ (void)ft_disableViewLoadingDurationForClass:(Class)viewControllerClass exception:(NSException *)exception{
    if (viewControllerClass == nil || viewControllerClass == UIViewController.class) {
        return;
    }
    objc_setAssociatedObject(viewControllerClass, viewLoadDurationDisabledKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    FTInnerLogError(@"disable view loading duration for class %@ exception: %@", NSStringFromClass(viewControllerClass), exception);
}
#pragma mark - Loading duration state

- (FTViewLoadingState *)ft_viewLoadingStateCreateIfNeeded:(BOOL)createIfNeeded{
    FTViewLoadingState *state = objc_getAssociatedObject(self, viewLoadingStateKey);
    if (state == nil && createIfNeeded) {
        state = [[FTViewLoadingState alloc] init];
        objc_setAssociatedObject(self, viewLoadingStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}
- (void)ft_resetViewLoadingMetricsWithStartTime:(uint64_t)startTime state:(FTViewLoadingState *)state{
    state.loadDuration = nil;
    state.hasViewLoadDurationGeneration = NO;
    state.viewLoadStartTime = startTime;
    state.hasViewLoadStartTime = YES;
    state.hasViewDidLoadDuration = NO;
    state.hasFirstViewWillAppearStartTime = NO;
    state.hasFirstViewWillLayoutSubviewsStartTime = NO;
    state.viewLoadDurationCalculated = NO;
    state.viewLoadDurationReported = NO;
    state.usesSwiftUIBaseLifecycleLoadingTime = NO;
    state.viewLoadGeneration = [UIViewController ft_currentViewLoadGeneration];
    state.hasViewLoadGeneration = YES;
}
- (void)ft_clearPendingViewLoadingMetricsForState:(FTViewLoadingState *)state{
    state.hasViewLoadStartTime = NO;
    state.hasViewDidLoadDuration = NO;
    state.hasFirstViewWillAppearStartTime = NO;
    state.hasFirstViewWillLayoutSubviewsStartTime = NO;
    state.hasViewLoadGeneration = NO;
}
- (BOOL)ft_clearExpiredViewLoadingMetricsIfNeededForState:(FTViewLoadingState *)state{
    if (state.hasViewLoadGeneration && state.viewLoadGeneration != [UIViewController ft_currentViewLoadGeneration]) {
        state.loadDuration = nil;
        state.hasViewLoadDurationGeneration = NO;
        [self ft_clearPendingViewLoadingMetricsForState:state];
        state.viewLoadDurationCalculated = YES;
        return YES;
    }
    return NO;
}
- (void)ft_clearExpiredViewLoadDurationIfNeededForState:(FTViewLoadingState *)state{
    if (state.loadDuration != nil && state.hasViewLoadDurationGeneration && state.viewLoadDurationGeneration != [UIViewController ft_currentViewLoadGeneration]) {
        state.loadDuration = nil;
        state.hasViewLoadDurationGeneration = NO;
    }
}
- (void)ft_storeViewLoadDuration:(NSNumber *)duration state:(FTViewLoadingState *)state{
    state.loadDuration = duration;
    state.viewLoadDurationGeneration = [UIViewController ft_currentViewLoadGeneration];
    state.hasViewLoadDurationGeneration = YES;
    [self ft_clearPendingViewLoadingMetricsForState:state];
    state.viewLoadDurationCalculated = YES;
}
- (void)ft_recordViewLoadDurationIfReadyForState:(FTViewLoadingState *)state viewDidAppearStartTime:(uint64_t)viewDidAppearStartTime{
    if (state == nil || state.viewLoadDurationCalculated || [self ft_clearExpiredViewLoadingMetricsIfNeededForState:state]) {
        return;
    }
    if (!state.hasViewDidLoadDuration) {
        return;
    }
    uint64_t displayStart = state.firstViewWillAppearStartTime;
    BOOL hasDisplayStart = state.hasFirstViewWillAppearStartTime;
    if (!state.hasFirstViewWillAppearStartTime) {
        displayStart = state.firstViewWillLayoutSubviewsStartTime;
        hasDisplayStart = state.hasFirstViewWillLayoutSubviewsStartTime;
    }
    if (!hasDisplayStart) {
        return;
    }
    uint64_t displayDuration = viewDidAppearStartTime >= displayStart ? viewDidAppearStartTime - displayStart : 0;
    [self ft_storeViewLoadDuration:@(state.viewDidLoadDuration + displayDuration) state:state];
}
- (void)ft_completeViewLoadingDurationForState:(FTViewLoadingState *)state viewDidAppearStartTime:(uint64_t)viewDidAppearStartTime{
    [self ft_clearExpiredViewLoadDurationIfNeededForState:state];
    [self ft_recordViewLoadDurationIfReadyForState:state viewDidAppearStartTime:viewDidAppearStartTime];
    if (!state.viewLoadDurationReported) {
        if (state.loadDuration == nil) {
            [self ft_storeViewLoadDuration:@(-1) state:state];
        }
        state.viewLoadDurationReported = YES;
    } else if (state.loadDuration == nil) {
        [self ft_storeViewLoadDuration:@0 state:state];
    }
}
- (void)ft_completeSwiftUIBaseLifecycleLoadingDurationForState:(FTViewLoadingState *)state viewDidAppearEndTime:(uint64_t)viewDidAppearEndTime{
    if (state == nil) {
        return;
    }
    [self ft_clearExpiredViewLoadDurationIfNeededForState:state];
    if (!state.viewLoadDurationReported) {
        BOOL hasValidStartTime = state.usesSwiftUIBaseLifecycleLoadingTime &&
            state.hasViewLoadStartTime &&
            ![self ft_clearExpiredViewLoadingMetricsIfNeededForState:state];
        if (hasValidStartTime) {
            uint64_t duration = viewDidAppearEndTime >= state.viewLoadStartTime ? viewDidAppearEndTime - state.viewLoadStartTime : 0;
            [self ft_storeViewLoadDuration:@(duration) state:state];
        } else {
            [self ft_storeViewLoadDuration:@(-1) state:state];
        }
        state.viewLoadDurationReported = YES;
    } else if (state.loadDuration == nil) {
        [self ft_storeViewLoadDuration:@0 state:state];
    }
}
- (void)ft_viewDidLoadWillStartWithState:(FTViewLoadingState *)state{
    if (state == nil) {
        return;
    }
    if (state.viewDidLoadDepth == 0) {
        [self ft_resetViewLoadingMetricsWithStartTime:FTDateUtil.systemTime state:state];
    }
    state.viewDidLoadDepth++;
}
- (void)ft_viewDidLoadDidEndWithState:(FTViewLoadingState *)state{
    if (state == nil || state.viewDidLoadDepth == 0) {
        return;
    }
    state.viewDidLoadDepth--;
    if (state.viewDidLoadDepth != 0 || [self ft_clearExpiredViewLoadingMetricsIfNeededForState:state] || !state.hasViewLoadStartTime) {
        return;
    }
    uint64_t end = FTDateUtil.systemTime;
    state.viewDidLoadDuration = end >= state.viewLoadStartTime ? end - state.viewLoadStartTime : 0;
    state.hasViewDidLoadDuration = YES;
}
- (void)ft_viewWillAppearWillStartWithState:(FTViewLoadingState *)state{
    if (state == nil) {
        return;
    }
    if (state.viewWillAppearDepth == 0 && !state.viewLoadDurationCalculated && ![self ft_clearExpiredViewLoadingMetricsIfNeededForState:state] && state.hasViewDidLoadDuration && !state.hasFirstViewWillAppearStartTime) {
        state.firstViewWillAppearStartTime = FTDateUtil.systemTime;
        state.hasFirstViewWillAppearStartTime = YES;
    }
    state.viewWillAppearDepth++;
}
- (void)ft_viewWillAppearDidEndWithState:(FTViewLoadingState *)state{
    if (state == nil || state.viewWillAppearDepth == 0) {
        return;
    }
    state.viewWillAppearDepth--;
    if (state.viewWillAppearDepth == 0) {
        [self ft_clearExpiredViewLoadingMetricsIfNeededForState:state];
    }
}
- (void)ft_viewWillLayoutSubviewsWillStartWithState:(FTViewLoadingState *)state{
    if (state == nil) {
        return;
    }
    if (state.viewWillLayoutSubviewsDepth == 0 && self.isViewLoaded && self.view.window != nil && !state.viewLoadDurationCalculated && ![self ft_clearExpiredViewLoadingMetricsIfNeededForState:state] && state.hasViewDidLoadDuration && !state.hasFirstViewWillLayoutSubviewsStartTime) {
        state.firstViewWillLayoutSubviewsStartTime = FTDateUtil.systemTime;
        state.hasFirstViewWillLayoutSubviewsStartTime = YES;
    }
    state.viewWillLayoutSubviewsDepth++;
}
- (void)ft_viewWillLayoutSubviewsDidEndWithState:(FTViewLoadingState *)state{
    if (state == nil || state.viewWillLayoutSubviewsDepth == 0) {
        return;
    }
    state.viewWillLayoutSubviewsDepth--;
    if (state.viewWillLayoutSubviewsDepth == 0 && !state.viewLoadDurationCalculated) {
        [self ft_clearExpiredViewLoadingMetricsIfNeededForState:state];
    }
}
- (NSString *)ft_viewControllerName{
    return NSStringFromClass([self class]);
}
- (BOOL)isBlackListContainsViewController{
    return FTViewControllerClassIsBlacklisted(self.class);
}
-(void)ft_markViewLoadingTimeUnavailableReported{
    FTViewLoadingState *state = [self ft_viewLoadingStateCreateIfNeeded:YES];
    if (state != nil && !state.viewLoadDurationReported) {
        state.viewLoadDurationReported = YES;
    }
}
-(void)ft_viewDidLoad{
    if (!atomic_load_explicit(&swiftUIViewLoadingTimeEnabled, memory_order_relaxed)) {
        [self ft_viewDidLoad];
        return;
    }
    BOOL isSwiftUIViewController = FTViewControllerClassIsFromSwiftUIImage(self.class);
    FTViewLoadingState *state = isSwiftUIViewController ? [self ft_viewLoadingStateCreateIfNeeded:YES] : nil;
    if (state != nil) {
        [self ft_resetViewLoadingMetricsWithStartTime:FTDateUtil.systemTime state:state];
        state.usesSwiftUIBaseLifecycleLoadingTime = YES;
    }
    [self ft_viewDidLoad];
}
-(void)ft_viewDidAppear:(BOOL)animated{
    if ([UIViewController ft_hasViewLoadingDurationInstrumentedClassInHierarchy:self.class]) {
        [self ft_viewDidAppear:animated];
        return;
    }

    FTViewLoadingState *state = [self ft_viewLoadingStateCreateIfNeeded:NO];
    BOOL isOutermostAppearance = state != nil && state.viewDidAppearDepth == 0;
    uint64_t viewDidAppearStartTime = isOutermostAppearance && !state.viewLoadDurationCalculated ? FTDateUtil.systemTime : 0;
    if (state != nil) {
        state.viewDidAppearDepth++;
    }
    [self ft_viewDidAppear:animated];
    if (state != nil && state.viewDidAppearDepth > 0) {
        state.viewDidAppearDepth--;
    }
    if (isOutermostAppearance && state.viewDidAppearDepth == 0) {
        if (state.usesSwiftUIBaseLifecycleLoadingTime) {
            [self ft_completeSwiftUIBaseLifecycleLoadingDurationForState:state viewDidAppearEndTime:FTDateUtil.systemTime];
        } else {
            [self ft_completeViewLoadingDurationForState:state viewDidAppearStartTime:viewDidAppearStartTime];
        }
    }
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:self animated:animated];
}
-(void)ft_viewDidDisappear:(BOOL)animated{
    [self ft_viewDidDisappear:animated];
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidDisappear:self animated:animated];
}
@end
#endif
