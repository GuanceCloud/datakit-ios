//
//  NSView+FTSRPrivacy.m
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
