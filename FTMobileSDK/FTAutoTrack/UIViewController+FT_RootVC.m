//
//  UIViewController+FT_RootVC.m
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UIViewController+FT_RootVC.h"
#import <objc/runtime.h>
#import "FTConstants.h"
#import "FTBaseInfoHander.h"
static char *viewLoadStartTimeKey = "viewLoadStartTimeKey";

@implementation UIViewController (FT_RootVC)
-(void)setViewLoadStartTime:(CFAbsoluteTime)viewLoadStartTime{
    objc_setAssociatedObject(self, &viewLoadStartTimeKey, @(viewLoadStartTime), OBJC_ASSOCIATION_COPY);
}
-(CFAbsoluteTime)viewLoadStartTime{
    return [objc_getAssociatedObject(self, &viewLoadStartTimeKey) doubleValue];
}
+ (NSString *)ft_getRootViewController{
    __block UIWindow* window = nil;
    __block NSString *name;
    [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes)
            {
                if (windowScene.activationState == UISceneActivationStateForegroundActive)
                {
                    window = windowScene.windows.firstObject;
                    break;
                }
            }
        }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // 这部分使用到的过期api
            window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        }

    name = NSStringFromClass([window.rootViewController class]);
    }];
    if( [name isKindOfClass:NSNull.class]
       ||name==nil){
        return FT_NULL_VALUE;
    }else{
        return  name;
    }
}

@end
