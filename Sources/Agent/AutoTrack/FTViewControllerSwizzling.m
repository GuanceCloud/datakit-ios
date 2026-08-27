//
//  FTViewControllerSwizzling.m
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#if TARGET_OS_IOS || TARGET_OS_TV
#import "FTViewControllerSwizzling.h"
#import "UIViewController+FTAutoTrack.h"
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>

@interface UIViewController (FTViewControllerSwizzlingInternal)
+ (NSArray<NSString *> *)ft_loadingTimeCandidateClassNamesFromClassNames:(NSArray<NSString *> *)classNames;
+ (NSUInteger)ft_installViewControllerLifecycleSwizzlesForClassNames:(NSArray<NSString *> *)classNames;
+ (BOOL)ft_installViewControllerLifecycleSwizzlesForClass:(Class)viewControllerClass;
+ (BOOL)ft_viewLoadingDurationInstrumentedForClass:(Class)viewControllerClass;
@end

@interface FTViewControllerSwizzling ()
@property (nonatomic, copy) NSArray<NSString *> *inAppIncludes;
@property (nonatomic, assign) BOOL scansLoadedFrameworks;
@property (nonatomic, assign) BOOL scansCurrentRootViewControllerHierarchy;
@property (nonatomic, strong, nullable) id sceneWillConnectObserver;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *completionBlocks;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL completed;
- (void)swizzleViewControllerHierarchyForWindows:(NSArray<UIWindow *> *)windows;
@end

static BOOL FTImagePathIsFromSystemLibrary(const char *imagePath) {
    return imagePath != NULL && strstr(imagePath, "/System/Library/") != NULL;
}

static NSArray<NSString *> *FTClassNamesInImage(NSString *imagePath) {
    if (imagePath.length == 0) {
        return @[];
    }
    unsigned int classCount = 0;
    const char **classNames = objc_copyClassNamesForImage(imagePath.UTF8String, &classCount);
    if (classNames == NULL || classCount == 0) {
        free(classNames);
        return @[];
    }
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:classCount];
    for (unsigned int index = 0; index < classCount; index++) {
        if (classNames[index] == NULL) {
            continue;
        }
        NSString *className = [NSString stringWithUTF8String:classNames[index]];
        if (className != nil) {
            [names addObject:className];
        }
    }
    free(classNames);
    return names;
}

static NSArray<NSString *> *FTLoadedImagePaths(void) {
    uint32_t imageCount = _dyld_image_count();
    NSMutableArray<NSString *> *imagePaths = [NSMutableArray arrayWithCapacity:imageCount];
    for (uint32_t index = 0; index < imageCount; index++) {
        const char *imagePath = _dyld_get_image_name(index);
        if (imagePath == NULL) {
            continue;
        }
        NSString *path = [NSString stringWithUTF8String:imagePath];
        if (path != nil) {
            [imagePaths addObject:path];
        }
    }
    return imagePaths;
}

static BOOL FTImagePathIsAtApplicationRoot(NSString *imagePath, NSString *appBundlePath) {
    NSString *appBundlePathPrefix = [appBundlePath stringByAppendingString:@"/"];
    if (![imagePath hasPrefix:appBundlePathPrefix]) {
        return NO;
    }
    NSString *relativePath = [imagePath substringFromIndex:appBundlePathPrefix.length];
    return [relativePath rangeOfString:@"/"].location == NSNotFound;
}

static NSArray<NSString *> *FTInAppImagePaths(NSArray<NSString *> *imagePaths, NSArray<NSString *> *inAppIncludes) {
    NSMutableOrderedSet<NSString *> *inAppImagePaths = [NSMutableOrderedSet orderedSet];
    for (NSString *imagePath in imagePaths) {
        for (NSString *inAppInclude in inAppIncludes) {
            if (inAppInclude.length == 0) {
                continue;
            }
            if ([inAppInclude.pathExtension isEqualToString:@"app"]) {
                if (FTImagePathIsAtApplicationRoot(imagePath, inAppInclude)) {
                    [inAppImagePaths addObject:imagePath];
                }
            } else if ([imagePath isEqualToString:inAppInclude]) {
                [inAppImagePaths addObject:imagePath];
            }
        }
    }
    return inAppImagePaths.array;
}

static NSArray<NSString *> *FTLoadedApplicationFrameworkImagePaths(NSArray<NSString *> *imagePaths, NSSet<NSString *> *excludedImagePaths) {
    NSMutableArray<NSString *> *frameworkImagePaths = [NSMutableArray array];
    for (NSString *path in imagePaths) {
        if ([excludedImagePaths containsObject:path] || FTImagePathIsFromSystemLibrary(path.UTF8String) || [path hasPrefix:@"/Applications/Xcode.app/"]) {
            continue;
        }
        for (NSString *pathComponent in path.pathComponents) {
            if ([pathComponent.pathExtension isEqualToString:@"framework"]) {
                [frameworkImagePaths addObject:path];
                break;
            }
        }
    }
    return frameworkImagePaths;
}

static NSArray<UIWindow *> *FTCurrentApplicationWindows(void) {
    if (![UIApplication respondsToSelector:@selector(sharedApplication)]) {
        return @[];
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    if (application == nil) {
        return @[];
    }
    NSMutableOrderedSet<UIWindow *> *windows = [NSMutableOrderedSet orderedSet];
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    id<UIApplicationDelegate> delegate = application.delegate;
    if ([delegate respondsToSelector:@selector(window)] && delegate.window != nil) {
        [windows addObject:delegate.window];
    }
    return windows.array;
}

static NSArray<UIViewController *> *FTViewControllerHierarchyFromRootViewController(UIViewController *rootViewController) {
    if (rootViewController == nil) {
        return @[];
    }
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    NSMutableArray<UIViewController *> *pendingViewControllers = [NSMutableArray arrayWithObject:rootViewController];
    NSMutableSet<UIViewController *> *visitedViewControllers = [NSMutableSet set];
    while (pendingViewControllers.count > 0) {
        UIViewController *viewController = pendingViewControllers.lastObject;
        [pendingViewControllers removeLastObject];
        if ([visitedViewControllers containsObject:viewController]) {
            continue;
        }
        [visitedViewControllers addObject:viewController];
        [viewControllers addObject:viewController];
        [pendingViewControllers addObjectsFromArray:viewController.childViewControllers];
        if (viewController.presentedViewController != nil) {
            [pendingViewControllers addObject:viewController.presentedViewController];
        }
    }
    return viewControllers;
}

@implementation FTViewControllerSwizzling

+ (instancetype)sharedInstance {
    static FTViewControllerSwizzling *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    return [self initWithInAppIncludes:nil scanLoadedFrameworks:YES];
}

- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes {
    return [self initWithInAppIncludes:inAppIncludes scanLoadedFrameworks:YES];
}

- (instancetype)initWithInAppIncludes:(NSArray<NSString *> *)inAppIncludes
                 scanLoadedFrameworks:(BOOL)scanLoadedFrameworks {
    self = [super init];
    if (self) {
        _scansLoadedFrameworks = scanLoadedFrameworks;
        if (inAppIncludes.count > 0) {
            _inAppIncludes = [inAppIncludes copy];
            _scansCurrentRootViewControllerHierarchy = NO;
        } else {
            NSString *appBundlePath = NSBundle.mainBundle.bundlePath;
            _inAppIncludes = appBundlePath.length > 0 ? @[appBundlePath] : @[];
            _scansCurrentRootViewControllerHierarchy = YES;
        }
        _completionBlocks = [NSMutableArray array];
    }
    return self;
}

- (void)swizzleLoadedViewControllerClassesWithCompletion:(dispatch_block_t)completion {
    void (^start)(void) = ^{
        if (completion != nil) {
            if (self.completed) {
                completion();
                return;
            }
            [self.completionBlocks addObject:[completion copy]];
        }
        if (self.started) {
            return;
        }
        self.started = YES;
        if (self.scansCurrentRootViewControllerHierarchy) {
            [self swizzleCurrentRootViewControllerHierarchy];
            [self observeFirstSceneConnectionForRootViewControllerHierarchy];
        }
        [self scanLoadedImagePaths];
    };
    if ([NSThread isMainThread]) {
        start();
    } else {
        dispatch_async(dispatch_get_main_queue(), start);
    }
}

- (void)scanLoadedImagePaths {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray<NSString *> *loadedImagePaths = FTLoadedImagePaths();
        NSArray<NSString *> *inAppImagePaths = FTInAppImagePaths(loadedImagePaths, self.inAppIncludes);
        NSMutableArray<NSString *> *inAppClassNames = [NSMutableArray array];
        for (NSString *inAppImagePath in inAppImagePaths) {
            [inAppClassNames addObjectsFromArray:FTClassNamesInImage(inAppImagePath)];
        }
        NSArray<NSString *> *inAppCandidateClassNames = [UIViewController ft_loadingTimeCandidateClassNamesFromClassNames:inAppClassNames];
        NSArray<NSString *> *frameworkImagePaths = self.scansLoadedFrameworks ? FTLoadedApplicationFrameworkImagePaths(loadedImagePaths, [NSSet setWithArray:inAppImagePaths]) : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:inAppCandidateClassNames];
            if (!self.scansLoadedFrameworks) {
                [self finish];
                return;
            }
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                NSMutableArray<NSString *> *frameworkClassNames = [NSMutableArray array];
                for (NSString *frameworkImagePath in frameworkImagePaths) {
                    [frameworkClassNames addObjectsFromArray:FTClassNamesInImage(frameworkImagePath)];
                }
                NSArray<NSString *> *frameworkCandidateClassNames = [UIViewController ft_loadingTimeCandidateClassNamesFromClassNames:frameworkClassNames];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIViewController ft_installViewControllerLifecycleSwizzlesForClassNames:frameworkCandidateClassNames];
                    [self finish];
                });
            });
        });
    });
}

- (void)finish {
    self.completed = YES;
    NSArray<dispatch_block_t> *completionBlocks = [self.completionBlocks copy];
    [self.completionBlocks removeAllObjects];
    for (dispatch_block_t completion in completionBlocks) {
        completion();
    }
}

- (void)observeFirstSceneConnectionForRootViewControllerHierarchy {
    if (self.sceneWillConnectObserver != nil) {
        return;
    }
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        __weak typeof(self) weakSelf = self;
        self.sceneWillConnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UISceneWillConnectNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            FTViewControllerSwizzling *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            [[NSNotificationCenter defaultCenter] removeObserver:strongSelf.sceneWillConnectObserver];
            strongSelf.sceneWillConnectObserver = nil;
            // UIScene posts this notification on the main thread after its delegate has
            // configured the scene's windows. Swizzle synchronously here, before the
            // root controller receives its initial lifecycle callbacks.
            if ([note.object isKindOfClass:UIWindowScene.class]) {
                [strongSelf swizzleViewControllerHierarchyForWindows:((UIWindowScene *)note.object).windows];
            }
        }];
    }
}

- (void)swizzleCurrentRootViewControllerHierarchy {
    [self swizzleViewControllerHierarchyForWindows:FTCurrentApplicationWindows()];
}

- (void)swizzleViewControllerHierarchyForWindows:(NSArray<UIWindow *> *)windows {
    for (UIWindow *window in windows) {
        for (UIViewController *viewController in FTViewControllerHierarchyFromRootViewController(window.rootViewController)) {
            Class viewControllerClass = viewController.class;
            if (![UIViewController ft_isCustomViewControllerClass:viewControllerClass] || [UIViewController ft_viewLoadingDurationInstrumentedForClass:viewControllerClass]) {
                continue;
            }
            [UIViewController ft_installViewControllerLifecycleSwizzlesForClass:viewControllerClass];
        }
    }
}

@end
#endif
