//
//  FTElectronWebViewRecorder.m
//  GuanceElectronWebView
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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
