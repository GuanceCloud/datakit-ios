//
//  FTWindowObserver.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTWindowObserver.h"

@implementation FTWindowObserver
-(UIWindow *)keyWindow{
    UIApplication *app = [UIApplication sharedApplication];
    if (@available(iOS 13.0, *)){
        UIScene *foregroundActiveScene;
        UIScene *foregroundInactiveScene;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                foregroundActiveScene = scene;
                break;
            }
            if (!foregroundInactiveScene && scene.activationState == UISceneActivationStateForegroundInactive) {
                foregroundInactiveScene = scene;
                // no break, we can have the active scene later in the set.
            }
        }
        UIScene *sceneToUse = foregroundActiveScene ? foregroundActiveScene : foregroundInactiveScene;
        UIWindowScene *windowScene = (UIWindowScene *)sceneToUse;
        if (@available(iOS 15.0, *)) {
            return windowScene.keyWindow;
        }
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
        return nil;
    }else if ([app.delegate respondsToSelector:@selector(window)]){
        return [app.delegate window];
    }else{
        return [app keyWindow];
    }
}
@end
