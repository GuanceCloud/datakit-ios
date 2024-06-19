//
//  UIView+FTSR.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

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
