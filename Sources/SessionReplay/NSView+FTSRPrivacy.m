//
//  NSView+FTSRPrivacy.m
//  SessionReplay
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import "NSView+FTSRPrivacy.h"
#import <objc/runtime.h>

static char *FTSRAppKitPrivacyOverridesKey = "FTSRAppKitPrivacyOverridesKey";

@implementation NSView (FTSRPrivacy)

- (FTSessionReplayPrivacyOverrides *)sessionReplayPrivacyOverrides {
    FTSessionReplayPrivacyOverrides *overrides = objc_getAssociatedObject(self, &FTSRAppKitPrivacyOverridesKey);
    if (!overrides) {
        overrides = [FTSessionReplayPrivacyOverrides new];
        objc_setAssociatedObject(self,
                                 &FTSRAppKitPrivacyOverridesKey,
                                 overrides,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return overrides;
}

@end

#endif
