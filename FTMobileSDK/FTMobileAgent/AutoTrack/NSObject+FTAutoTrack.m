//
//  NSObject+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "NSObject+FTAutoTrack.h"
#import <objc/runtime.h>
@implementation NSObject (FTAutoTrack)
static void *const kFTDelegateProxyClassName = (void *)&kFTDelegateProxyClassName;

- (NSString *)dataFlux_className {
    return objc_getAssociatedObject(self, kFTDelegateProxyClassName);
}

- (void)setDataFlux_className:(NSString *)dataFlux_className {
    objc_setAssociatedObject(self, kFTDelegateProxyClassName, dataFlux_className, OBJC_ASSOCIATION_COPY);
}
@end
