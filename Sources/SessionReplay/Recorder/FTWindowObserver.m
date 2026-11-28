//
//  FTWindowObserver.m
//  SessionReplay
//
//  Created by hulilei on 2023/7/17.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTWindowObserver.h"

#if TARGET_OS_OSX
@interface FTWindowObserver ()
@property (nonatomic, copy) FTSRKeyWindowProvider keyWindowProvider;
@end
#endif

@implementation FTWindowObserver
#if TARGET_OS_IOS
- (nullable UIApplication *)_findApp{
    if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
        return [UIApplication performSelector:@selector(sharedApplication)];
    }
    return nil;
}
- (UIWindowScene *)_activeWindowScene{
    UIApplication *app = [self _findApp];
    if (app == nil) {
        return nil;
    }

    UIScene *foregroundActiveScene = nil;
    UIScene *foregroundInactiveScene = nil;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        if (scene.activationState == UISceneActivationStateForegroundActive) {
            foregroundActiveScene = scene;
            break;
        }

        if (!foregroundInactiveScene &&
            scene.activationState == UISceneActivationStateForegroundInactive) {
            foregroundInactiveScene = scene;
        }
    }

    UIScene *sceneToUse = foregroundActiveScene ?: foregroundInactiveScene;
    return (UIWindowScene *)sceneToUse;
}
-(UIWindow *)keyWindow{
    // Prevent compilation failure in WidgetExtension environment
    UIApplication *app = [self _findApp];
    if(app == nil){
        return nil;
    }
    UIWindowScene *windowScene = [self _activeWindowScene];
    return windowScene.keyWindow;
}
- (NSArray<UIWindow *>*)windows{
    UIApplication *app = [self _findApp];
    if(app == nil){
        return nil;
    }
    UIWindowScene *windowScene = [self _activeWindowScene];
    return windowScene.windows;
}
- (NSArray<FTSRPlatformView *> *)rootViews {
    return self.windows;
}
- (FTSRPlatformView *)referenceView {
    return self.keyWindow;
}
#elif TARGET_OS_OSX
- (instancetype)init {
    return [self initWithKeyWindowProvider:^NSWindow * _Nullable{
        return NSApplication.sharedApplication.keyWindow;
    }];
}
- (instancetype)initWithKeyWindowProvider:(FTSRKeyWindowProvider)keyWindowProvider {
    self = [super init];
    if (self) {
        _keyWindowProvider = [keyWindowProvider copy];
    }
    return self;
}
- (NSWindow *)keyWindow {
    return self.keyWindowProvider ? self.keyWindowProvider() : nil;
}
- (NSArray<FTSRPlatformView *> *)rootViews {
    NSView *contentView = self.keyWindow.contentView;
    return contentView ? @[contentView] : nil;
}
- (FTSRPlatformView *)referenceView {
    return self.keyWindow.contentView;
}
#endif
@end

#endif
