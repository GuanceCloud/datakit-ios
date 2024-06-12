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
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if(scene.activationState == UISceneActivationStateForegroundActive){
                return scene.windows.firstObject;
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
