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
#import "NSDate+FTUtil.h"
#import "FTSwizzler.h"
#import "FTViewControllerSwizzling.h"
#import <string.h>
#import <stdatomic.h>
#import <os/lock.h>

@interface FTViewLoadingState : NSObject
@property (nonatomic, strong, nullable) NSNumber *loadDuration;
@property (nonatomic, strong, nullable) NSNumber *viewLoadStartEpochNs;
@property (nonatomic, assign) BOOL viewDidLoadInProgress;
@property (nonatomic, assign) BOOL viewWillAppearInProgress;
@property (nonatomic, assign) BOOL viewWillLayoutSubviewsInProgress;
@property (nonatomic, assign) BOOL viewDidAppearInProgress;
@property (nonatomic, assign) NSUInteger viewLoadGeneration;
@property (nonatomic, assign) NSUInteger viewLoadDurationGeneration;
@property (nonatomic, assign) uint64_t viewLoadStartTime;
@property (nonatomic, assign) uint64_t viewDidLoadEndTime;
@property (nonatomic, assign) uint64_t firstViewDidAppearStartTime;
@property (nonatomic, assign) uint64_t firstViewWillAppearStartTime;
@property (nonatomic, assign) uint64_t firstViewWillLayoutSubviewsStartTime;
@property (nonatomic, assign) BOOL hasViewLoadStartTime;
@property (nonatomic, assign) BOOL hasViewDidLoadEndTime;
@property (nonatomic, assign) BOOL hasFirstViewDidAppearStartTime;
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
static os_unfair_lock viewLoadingPolicyLock = OS_UNFAIR_LOCK_INIT;
static BOOL viewLoadingTimeEnabled = YES;
static NSSet<NSString *> *viewLoadingClassNameExcludes;

static BOOL FTShouldCollectViewLoadingTimeForClassName(NSString *className) {
    os_unfair_lock_lock(&viewLoadingPolicyLock);
    BOOL enabled = viewLoadingTimeEnabled;
    NSSet<NSString *> *excludes = viewLoadingClassNameExcludes;
    os_unfair_lock_unlock(&viewLoadingPolicyLock);
    if (!enabled || className.length == 0) {
        return NO;
    }
    return ![excludes containsObject:className];
}

static BOOL FTShouldCollectViewLoadingTimeForClass(Class controllerClass) {
    const char *name = controllerClass != Nil ? class_getName(controllerClass) : NULL;
    return name != NULL && FTShouldCollectViewLoadingTimeForClassName([NSString stringWithUTF8String:name]);
}

static BOOL FTViewControllerClassIsBlacklisted(Class viewControllerClass) {
    @try {
        NSDictionary *blackList = [BlacklistedVCClassNames ft_blacklistedViewControllerClassNames][FT_BLACK_LIST_VIEW];
        for (NSString *className in blackList[@"public"]) {
            Class blacklistedClass = NSClassFromString(className);
            if (blacklistedClass == Nil) {
                continue;
            }
            // Scanning unused classes must not send them class messages: even an
            // inherited +isSubclassOfClass: can run application +initialize code.
            for (Class currentClass = viewControllerClass; currentClass != Nil; currentClass = class_getSuperclass(currentClass)) {
                if (currentClass == blacklistedClass) {
                    return YES;
                }
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

static BOOL FTViewControllerClassIsFromSwiftUIImage(Class viewControllerClass) {
    // bundleForClass: may resolve class methods and run +initialize on an unused class.
    const char *imagePath = class_getImageName(viewControllerClass);
    return imagePath != NULL && strstr(imagePath, "/SwiftUI.framework/") != NULL;
}

@implementation UIViewController (FTAutoTrack)
- (NSNumber *)ft_viewLoadStartEpochNs{
    if (!FTShouldCollectViewLoadingTimeForClass(object_getClass(self))) return nil;
    return [self ft_viewLoadingStateCreateIfNeeded:NO].viewLoadStartEpochNs;
}
+ (NSUInteger)ft_currentViewLoadGeneration{
    return (NSUInteger)atomic_load_explicit(&viewLoadGeneration, memory_order_relaxed);
}
+ (void)ft_invalidatePendingViewLoadDurations{
    atomic_fetch_add_explicit(&viewLoadGeneration, 1, memory_order_relaxed);
}
+ (void)ft_setSwiftUIViewLoadingTimeEnabled:(BOOL)enabled{
    atomic_store_explicit(&swiftUIViewLoadingTimeEnabled, enabled, memory_order_relaxed);
}
+ (void)ft_setViewLoadingTimeEnabled:(BOOL)enabled{
    // Preserve class exclusions when automatic tracking stops or restarts.
    os_unfair_lock_lock(&viewLoadingPolicyLock);
    BOOL changed = viewLoadingTimeEnabled != enabled;
    viewLoadingTimeEnabled = enabled;
    os_unfair_lock_unlock(&viewLoadingPolicyLock);
    if (changed) {
        [self ft_invalidatePendingViewLoadDurations];
    }
}
+ (void)ft_configureViewLoadingTimeEnabled:(BOOL)enabled classNameExcludes:(NSSet<NSString *> *)excludes{
    NSMutableSet<NSString *> *validNames = [NSMutableSet set];
    for (id name in excludes) {
        if ([name isKindOfClass:NSString.class] && [name length] > 0) [validNames addObject:[name copy]];
    }
    NSSet<NSString *> *snapshot = [validNames copy];
    os_unfair_lock_lock(&viewLoadingPolicyLock);
    viewLoadingTimeEnabled = enabled;
    viewLoadingClassNameExcludes = snapshot;
    os_unfair_lock_unlock(&viewLoadingPolicyLock);
    [self ft_invalidatePendingViewLoadDurations];
}
+ (BOOL)ft_shouldCollectViewLoadingTimeForClass:(Class)controllerClass{
    return FTShouldCollectViewLoadingTimeForClass(controllerClass);
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
    if (!FTShouldCollectViewLoadingTimeForClass(object_getClass(self))) return nil;
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
        state.hasViewLoadStartTime = NO;
        state.viewLoadStartEpochNs = nil;
    }
}

#pragma mark - UIViewController loading duration swizzling

+ (void)ft_swizzleLoadedCustomViewControllerClasses{
    [[FTViewControllerSwizzling sharedInstance] refreshLoadedViewControllerClasses];
}
+ (NSArray<NSString *> *)ft_loadingTimeCandidateClassNamesFromClassNames:(NSArray<NSString *> *)classNames{
    NSMutableArray<NSString *> *candidateClassNames = [NSMutableArray array];
    for (NSString *className in classNames) {
        // Exclude by name before touching runtime metadata for an unused class.
        if (!FTShouldCollectViewLoadingTimeForClassName(className)) continue;
        // Keep class names across queues and inspect runtime metadata only. Class messages
        // and Foundation class queries can run +initialize before application use.
        // Lifecycle method replacement remains confined to the main thread.
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
    if (viewControllerClass == Nil || !FTShouldCollectViewLoadingTimeForClass(viewControllerClass) || [self ft_viewLoadingDurationDisabledForClass:viewControllerClass]) {
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
            if (!FTShouldCollectViewLoadingTimeForClass(object_getClass(viewController))) {
                FTSWCallOriginal();
                return;
            }
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:YES];
            if (state == nil || state.viewDidLoadInProgress) {
                FTSWCallOriginal();
                return;
            }
            state.viewDidLoadInProgress = YES;
            @try {
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
            } @finally {
                state.viewDidLoadInProgress = NO;
            }
        }), FTSwizzlerModeOncePerClass, viewDidLoadSwizzleKey);
        FTSwizzlerInstanceMethod(viewControllerClass,
                                 @selector(viewWillAppear:),
                                 FTSWReturnType(void),
                                 FTSWArguments(BOOL animated),
                                 FTSWReplacement({
            UIViewController *viewController = (UIViewController *)self;
            if (!FTShouldCollectViewLoadingTimeForClass(object_getClass(viewController))) {
                FTSWCallOriginal(animated);
                return;
            }
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:NO];
            if (state == nil || state.viewLoadDurationCalculated || state.viewWillAppearInProgress || state.hasFirstViewWillAppearStartTime) {
                FTSWCallOriginal(animated);
                return;
            }
            state.viewWillAppearInProgress = YES;
            @try {
                @try {
                    [viewController ft_viewWillAppearWillStartWithState:state];
                } @catch (NSException *exception) {
                    FTInnerLogError(@"viewWillAppear start record exception: %@", exception);
                }
                FTSWCallOriginal(animated);
                @try {
                    [viewController ft_clearExpiredViewLoadingMetricsIfNeededForState:state];
                } @catch (NSException *exception) {
                    FTInnerLogError(@"viewWillAppear end record exception: %@", exception);
                }
            } @finally {
                state.viewWillAppearInProgress = NO;
            }
        }), FTSwizzlerModeOncePerClass, viewWillAppearSwizzleKey);
        FTSwizzlerInstanceMethod(viewControllerClass,
                                 @selector(viewWillLayoutSubviews),
                                 FTSWReturnType(void),
                                 FTSWArguments(),
                                 FTSWReplacement({
            UIViewController *viewController = (UIViewController *)self;
            if (!FTShouldCollectViewLoadingTimeForClass(object_getClass(viewController))) {
                FTSWCallOriginal();
                return;
            }
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:NO];
            if (state == nil || state.viewLoadDurationCalculated || state.viewWillLayoutSubviewsInProgress || state.hasFirstViewWillAppearStartTime || state.hasFirstViewWillLayoutSubviewsStartTime || !state.hasViewDidLoadEndTime) {
                FTSWCallOriginal();
                return;
            }
            state.viewWillLayoutSubviewsInProgress = YES;
            @try {
                @try {
                    [viewController ft_viewWillLayoutSubviewsWillStartWithState:state];
                } @catch (NSException *exception) {
                    FTInnerLogError(@"viewWillLayoutSubviews start record exception: %@", exception);
                }
                FTSWCallOriginal();
                @try {
                    [viewController ft_clearExpiredViewLoadingMetricsIfNeededForState:state];
                } @catch (NSException *exception) {
                    FTInnerLogError(@"viewWillLayoutSubviews end record exception: %@", exception);
                }
            } @finally {
                state.viewWillLayoutSubviewsInProgress = NO;
            }
        }), FTSwizzlerModeOncePerClass, viewWillLayoutSubviewsSwizzleKey);
        FTSwizzlerInstanceMethod(viewControllerClass,
                                 @selector(viewDidAppear:),
                                 FTSWReturnType(void),
                                 FTSWArguments(BOOL animated),
                                 FTSWReplacement({
            UIViewController *viewController = (UIViewController *)self;
            if (!FTShouldCollectViewLoadingTimeForClass(object_getClass(viewController))) {
                FTSWCallOriginal(animated);
                return;
            }
            FTViewLoadingState *state = [viewController ft_viewLoadingStateCreateIfNeeded:YES];
            if (state == nil || state.viewDidAppearInProgress) {
                FTSWCallOriginal(animated);
                return;
            }
            state.viewDidAppearInProgress = YES;
            @try {
                if (!state.viewLoadDurationCalculated && !state.hasFirstViewDidAppearStartTime) {
                    state.firstViewDidAppearStartTime = FTDateUtil.systemTime;
                    state.hasFirstViewDidAppearStartTime = YES;
                }
                [viewController ft_completeViewLoadingDurationForState:state viewDidAppearStartTime:state.firstViewDidAppearStartTime];
                [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:viewController animated:animated];
                FTSWCallOriginal(animated);
            } @finally {
                state.viewDidAppearInProgress = NO;
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
    if (!FTShouldCollectViewLoadingTimeForClass(viewControllerClass)) return NO;
    if (![self ft_isViewControllerSubclass:viewControllerClass] || class_getImageName(viewControllerClass) == NULL || FTViewControllerClassIsFromSystemImage(viewControllerClass)) {
        return NO;
    }
    // System images are already excluded above, including the system SwiftUI framework.
    return !FTViewControllerClassIsBlacklisted(viewControllerClass);
}
+ (BOOL)ft_shouldTrackDefaultViewControllerClass:(Class)viewControllerClass{
    return viewControllerClass != Nil && !FTViewControllerClassIsBlacklisted(viewControllerClass) && !FTViewControllerClassIsFromSwiftUIImage(viewControllerClass);
}
+ (BOOL)ft_hasViewLoadingDurationInstrumentedClassInHierarchy:(Class)viewControllerClass{
    if (!FTShouldCollectViewLoadingTimeForClass(viewControllerClass)) return NO;
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
    state.viewLoadStartEpochNs = @([NSDate ft_currentNanosecondTimeStamp]);
    state.hasViewLoadDurationGeneration = NO;
    state.viewLoadStartTime = startTime;
    state.hasViewLoadStartTime = YES;
    state.hasViewDidLoadEndTime = NO;
    state.hasFirstViewDidAppearStartTime = NO;
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
    state.viewLoadStartEpochNs = nil;
    state.hasViewDidLoadEndTime = NO;
    state.hasFirstViewDidAppearStartTime = NO;
    state.hasFirstViewWillAppearStartTime = NO;
    state.hasFirstViewWillLayoutSubviewsStartTime = NO;
    state.hasViewLoadGeneration = NO;
}
- (BOOL)ft_clearExpiredViewLoadingMetricsIfNeededForState:(FTViewLoadingState *)state{
    if (state.hasViewLoadGeneration && state.viewLoadGeneration != [UIViewController ft_currentViewLoadGeneration]) {
        state.loadDuration = nil;
        state.viewLoadStartEpochNs = nil;
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
        state.viewLoadStartEpochNs = nil;
    }
}
- (void)ft_storeViewLoadDuration:(NSNumber *)duration state:(FTViewLoadingState *)state{
    BOOL hasLoadStart = state.hasViewLoadStartTime && duration.longLongValue > 0;
    NSNumber *loadStartEpochNs = hasLoadStart ? state.viewLoadStartEpochNs : nil;
    state.loadDuration = duration;
    state.viewLoadDurationGeneration = [UIViewController ft_currentViewLoadGeneration];
    state.hasViewLoadDurationGeneration = YES;
    [self ft_clearPendingViewLoadingMetricsForState:state];
    state.hasViewLoadStartTime = hasLoadStart;
    state.viewLoadStartEpochNs = loadStartEpochNs;
    state.viewLoadDurationCalculated = YES;
}
- (void)ft_recordViewLoadDurationIfReadyForState:(FTViewLoadingState *)state viewDidAppearStartTime:(uint64_t)viewDidAppearStartTime{
    if (state == nil || state.viewLoadDurationCalculated || [self ft_clearExpiredViewLoadingMetricsIfNeededForState:state]) {
        return;
    }
    if (!state.hasViewDidLoadEndTime) {
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
    uint64_t loadDuration = state.viewDidLoadEndTime >= state.viewLoadStartTime ? state.viewDidLoadEndTime - state.viewLoadStartTime : 0;
    [self ft_storeViewLoadDuration:@(loadDuration + displayDuration) state:state];
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
// Only the owning (outermost) wrapper invokes these sampling helpers.
- (void)ft_viewDidLoadWillStartWithState:(FTViewLoadingState *)state{
    [self ft_resetViewLoadingMetricsWithStartTime:FTDateUtil.systemTime state:state];
}
- (void)ft_viewDidLoadDidEndWithState:(FTViewLoadingState *)state{
    uint64_t end = FTDateUtil.systemTime;
    if ([self ft_clearExpiredViewLoadingMetricsIfNeededForState:state] || !state.hasViewLoadStartTime) {
        return;
    }
    state.viewDidLoadEndTime = end;
    state.hasViewDidLoadEndTime = YES;
}
- (void)ft_viewWillAppearWillStartWithState:(FTViewLoadingState *)state{
    if (![self ft_clearExpiredViewLoadingMetricsIfNeededForState:state] && state.hasViewDidLoadEndTime) {
        state.firstViewWillAppearStartTime = FTDateUtil.systemTime;
        state.hasFirstViewWillAppearStartTime = YES;
    }
}
- (void)ft_viewWillLayoutSubviewsWillStartWithState:(FTViewLoadingState *)state{
    if (![self ft_clearExpiredViewLoadingMetricsIfNeededForState:state] && self.isViewLoaded && self.view.window != nil) {
        state.firstViewWillLayoutSubviewsStartTime = FTDateUtil.systemTime;
        state.hasFirstViewWillLayoutSubviewsStartTime = YES;
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
    if (!atomic_load_explicit(&swiftUIViewLoadingTimeEnabled, memory_order_relaxed) ||
        !FTShouldCollectViewLoadingTimeForClass(object_getClass(self))) {
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

    FTViewLoadingState *state = FTShouldCollectViewLoadingTimeForClass(object_getClass(self)) ? [self ft_viewLoadingStateCreateIfNeeded:NO] : nil;
    if (state.viewDidAppearInProgress) {
        [self ft_viewDidAppear:animated];
        return;
    }
    BOOL isOutermostAppearance = state != nil;
    uint64_t viewDidAppearStartTime = isOutermostAppearance && !state.viewLoadDurationCalculated ? FTDateUtil.systemTime : 0;
    if (state != nil) {
        state.viewDidAppearInProgress = YES;
    }
    @try {
        if (isOutermostAppearance) {
            if (state.usesSwiftUIBaseLifecycleLoadingTime) {
                [self ft_completeSwiftUIBaseLifecycleLoadingDurationForState:state viewDidAppearEndTime:FTDateUtil.systemTime];
            } else {
                [self ft_completeViewLoadingDurationForState:state viewDidAppearStartTime:viewDidAppearStartTime];
            }
        }
        if (!state || isOutermostAppearance) {
            [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:self animated:animated];
        }
        [self ft_viewDidAppear:animated];
    } @finally {
        if (state != nil) state.viewDidAppearInProgress = NO;
    }
}
-(void)ft_viewDidDisappear:(BOOL)animated{
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidDisappear:self animated:animated];
    [self ft_viewDidDisappear:animated];
}
@end
#endif
