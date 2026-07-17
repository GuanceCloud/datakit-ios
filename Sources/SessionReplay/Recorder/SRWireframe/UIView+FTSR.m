//
//  UIView+FTSR.m
//  SessionReplay
//
//  Created by hulilei on 2023/8/3.
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

#import "UIView+FTSR.h"
#import <objc/runtime.h>

static char *associatedNodeIDKey = "FTSRNodeIDKey";
static char *associatedNodeIDsKey = "FTSRNodeIDsKey";

@implementation UIView (FTSR)

-(void)setSRNodeID:(NSDictionary *)nodeID{
    objc_setAssociatedObject(self, &associatedNodeIDKey, nodeID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSDictionary *)SRNodeID{
    return objc_getAssociatedObject(self, &associatedNodeIDKey);
}
-(NSDictionary *)SRNodeIDs{
    return  objc_getAssociatedObject(self, &associatedNodeIDsKey);
}
-(void)setSRNodeIDs:(NSDictionary *)nodeIDs{
    objc_setAssociatedObject(self, &associatedNodeIDsKey, nodeIDs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(BOOL)usesDarkMode{
    if (@available(iOS 12.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    } else {
        return NO;
    }
}
@end

#endif
