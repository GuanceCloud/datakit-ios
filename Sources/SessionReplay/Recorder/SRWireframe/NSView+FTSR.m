//
//  NSView+FTSR.m
//  SessionReplay
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import "NSView+FTSR.h"
#import <objc/runtime.h>

static char *FTSRAppKitNodeIDKey = "FTSRAppKitNodeIDKey";
static char *FTSRAppKitNodeIDsKey = "FTSRAppKitNodeIDsKey";

@implementation NSView (FTSR)

- (void)setSRNodeID:(NSDictionary *)nodeID {
    objc_setAssociatedObject(self, &FTSRAppKitNodeIDKey, nodeID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)SRNodeID {
    return objc_getAssociatedObject(self, &FTSRAppKitNodeIDKey);
}

- (void)setSRNodeIDs:(NSDictionary *)nodeIDs {
    objc_setAssociatedObject(self, &FTSRAppKitNodeIDsKey, nodeIDs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *)SRNodeIDs {
    return objc_getAssociatedObject(self, &FTSRAppKitNodeIDsKey);
}

- (BOOL)usesDarkMode {
    if (@available(macOS 10.14, *)) {
        NSAppearanceName bestMatch = [self.effectiveAppearance
            bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        return [bestMatch isEqualToString:NSAppearanceNameDarkAqua];
    }
    return NO;
}

@end

#endif
