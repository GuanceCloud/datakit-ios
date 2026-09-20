//
//  FTElectronWebViewRecorder.m
//  GuanceElectronWebView
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
#import "FTElectronWebViewRecorder.h"
#import "FTElectronWebViewHandler+Private.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshot.h"
#import "FTWKWebViewRecorder.h"
#import "FTWKWebViewJavascriptBridge.h"

@implementation FTElectronWebViewRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        _identifier = NSUUID.UUID.UUIDString;
    }
    return self;
}

- (FTSRNodeSemantics *)recorder:(NSView *)view
                     attributes:(FTViewAttributes *)attributes
                        context:(FTViewTreeRecordingContext *)context {
    if (![NSStringFromClass(view.class)
            isEqualToString:@"WebContentsViewCocoa"]) {
        return nil;
    }

    FTElectronWebViewDescriptor *descriptor =
        [[FTElectronWebViewHandler sharedInstance]
            descriptorForNativeView:view
                              frame:attributes.frame];
    if (!descriptor || !descriptor.visible || !attributes.isVisible) {
        return [[FTIgnoredElement alloc]
            initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    }

    [context.webViewSlotIDs addObject:@(descriptor.slotID)];
    [[FTElectronWebViewHandler sharedInstance]
        consumeFullSnapshotRequestForDescriptor:descriptor];

    FTWKWebViewBuilder *builder = [[FTWKWebViewBuilder alloc] init];
    builder.slotID = descriptor.slotID;
    builder.attributes = attributes;
    builder.linkRUMKeysInfo = descriptor.bindInfo.linkRUMKeysInfo;

    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}

@end


#endif
