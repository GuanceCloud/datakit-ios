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
#if TARGET_OS_IOS

#import "FTWindowObserver.h"

@implementation FTWindowObserver
- (nullable UIApplication *)_findApp{
    if ([UIApplication respondsToSelector:@selector(sharedApplication)]) {
        return [UIApplication performSelector:@selector(sharedApplication)];
    }
    return nil;
}
- (UIWindowScene *)_activeWindowScene  API_AVAILABLE(ios(13.0)){
    UIApplication *app = [self _findApp];
    if (app == nil) {
        return nil;
    }

    if (@available(iOS 13.0, *)) {
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

    return nil;
}
-(UIWindow *)keyWindow{
    // Prevent compilation failure in WidgetExtension environment
    UIApplication *app = [self _findApp];
    if(app == nil){
        return nil;
    }
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = [self _activeWindowScene];
        if (!windowScene) return nil;
        
        if (@available(iOS 15.0, *)) {
            return windowScene.keyWindow;
        }
        
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
        return nil;
    }
    if ([app.delegate respondsToSelector:@selector(window)]){
        return [app.delegate window];
    }else{
        return [app keyWindow];
    }
}
- (NSArray<UIWindow *>*)windows{
    UIApplication *app = [self _findApp];
    if(app == nil){
        return nil;
    }
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = [self _activeWindowScene];
        return windowScene.windows;
    }
    return [app windows];
}
@end

#endif
