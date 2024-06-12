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

@implementation UITouch (FTIdentifier)
-(void)setIdentifier:(int )identifier{
    objc_setAssociatedObject(self, &touchIdentifier, @(identifier), OBJC_ASSOCIATION_COPY);
}
-(int )identifier{
    return [objc_getAssociatedObject(self, &touchIdentifier) intValue];
}
@end
