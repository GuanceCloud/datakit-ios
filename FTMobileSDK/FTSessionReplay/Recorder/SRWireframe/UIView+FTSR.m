//
//  UIView+FTSR.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "UIView+FTSR.h"
#import <objc/runtime.h>

static char *SRViewID = "FTSRViewID";
static char *SRViewIDs = "FTSRViewIDs";

@implementation UIView (FTSR)

-(void)setSRViewID:(int)viewID{
    objc_setAssociatedObject(self, &SRViewID, @(viewID), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(int)SRViewID{
    id viewid = objc_getAssociatedObject(self, &SRViewID);
    if (viewid != nil){
        return [viewid intValue];
    }
    return -1;
}
-(NSArray *)SRViewIDs{
    return  objc_getAssociatedObject(self, &SRViewIDs);
}
-(void)setSRViewIDs:(NSArray *)viewIDs{
    objc_setAssociatedObject(self, &SRViewIDs, viewIDs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(BOOL)usesDarkMode{
    if (@available(iOS 12.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    } else {
        return NO;
    }
}
@end
