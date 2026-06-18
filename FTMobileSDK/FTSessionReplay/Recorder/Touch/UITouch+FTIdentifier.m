//
//  UITouch+FTIdentifier.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/12.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "UITouch+FTIdentifier.h"
#import <objc/runtime.h>
static char *touchIdentifier = "FTTouchIdentifier";
static char *kTouchPrivacyOverride = "kTouchPrivacyOverride";

@implementation UITouch (FTIdentifier)
-(void)setIdentifier:(NSNumber*)identifier{
    objc_setAssociatedObject(self, &touchIdentifier, identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSNumber*)identifier{
    return objc_getAssociatedObject(self, &touchIdentifier);
}
-(void)setTouchPrivacyOverride:(NSNumber *)touchPrivacyOverride{
    objc_setAssociatedObject(self, &kTouchPrivacyOverride, touchPrivacyOverride, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSNumber *)touchPrivacyOverride{
    return objc_getAssociatedObject(self, &kTouchPrivacyOverride);
}

@end
