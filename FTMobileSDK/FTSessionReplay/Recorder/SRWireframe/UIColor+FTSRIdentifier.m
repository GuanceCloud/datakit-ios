//
//  UIColor+FTSRIdentifier.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "UIColor+FTSRIdentifier.h"
#import <objc/runtime.h>
static char *srIdentifierKey = "FTSRIdentifierKey";

@implementation UIColor (FTSRIdentifier)
-(void)setSrIdentifier:(NSString *)srIdentifier{
    objc_setAssociatedObject(self, &srIdentifierKey, srIdentifier, OBJC_ASSOCIATION_RETAIN);
}
- (NSString *)srIdentifier{
    NSString *hash = objc_getAssociatedObject(self, &srIdentifierKey);
    if(hash && hash.length>0){
        return hash;
    }
    NSString *newHash = [self computeIdentifier];
    self.srIdentifier = newHash;
    return newHash;
}
- (NSString *)computeIdentifier{
    CGFloat r = 0;
    CGFloat g = 0;
    CGFloat b = 0;
    CGFloat a = 0;
    [self getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"%02X%02X%02X%02X",(int)round(r * 255), (int)round(g * 255), (int)round(b * 255), (int)round(a * 255)];
}
@end
