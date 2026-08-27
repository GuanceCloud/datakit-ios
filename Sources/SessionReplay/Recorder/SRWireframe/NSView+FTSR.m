//
//  NSView+FTSR.m
//  SessionReplay
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
