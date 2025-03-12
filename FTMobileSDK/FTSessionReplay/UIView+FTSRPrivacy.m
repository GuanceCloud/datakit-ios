//
//  UIView+FTSRPrivacy.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/11.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "UIView+FTSRPrivacy.h"
#import <objc/runtime.h>
static char *associatedOverridesKey = "associatedOverridesKey";

@implementation UIView (FTSRPrivacy)

-(FTSessionReplayPrivacyOverrides *)sessionReplayPrivacyOverrides{
    FTSessionReplayPrivacyOverrides *overrides = [self _privacyOverrides];
    if(overrides){
        return overrides;
    }
    overrides = [FTSessionReplayPrivacyOverrides new];
    objc_setAssociatedObject(self, &associatedOverridesKey, overrides, OBJC_ASSOCIATION_RETAIN);
    return overrides;
}

- (FTSessionReplayPrivacyOverrides *)_privacyOverrides{
    return objc_getAssociatedObject(self, &associatedOverridesKey);
}
@end
