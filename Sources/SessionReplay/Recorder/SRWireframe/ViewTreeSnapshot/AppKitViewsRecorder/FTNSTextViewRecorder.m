//
//  FTNSTextViewRecorder.m
//  SessionReplay AppKit views
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

#import "FTAppKitViewRecorders.h"
#import <AppKit/AppKit.h>
#import "FTAppKitRecorderSupport.h"
#import "FTSRTextObfuscatingFactory.h"
#import "FTSRViewID.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshot.h"

@implementation FTNSTextViewRecorder
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
    if (![view isKindOfClass:NSTextView.class]) {
        return nil;
    }
    NSTextView *textView = (NSTextView *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    FTTextAndInputPrivacyLevel privacy =
        [attributes resolveTextAndInputPrivacyLevel:context.recorder];
    FTNSTextBuilder *builder = [FTNSTextBuilder new];
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    builder.attributes = attributes;
    builder.text = textView.string ?: @"";
    builder.fontSize = textView.font.pointSize ?: NSFont.systemFontSize;
    builder.fontFamily = textView.font.familyName;
    builder.textColor =
        FTSRAppKitHexColor(textView.textColor, textView.effectiveAppearance, @"#000000FF");
    builder.backgroundColor = textView.drawsBackground
        ? FTSRAppKitHexColor(textView.backgroundColor,
                            textView.effectiveAppearance,
                            @"#FFFFFFFF")
        : nil;
    builder.alignment = textView.defaultParagraphStyle.alignment;
    builder.lineBreakMode = NSLineBreakByWordWrapping;
    NSSize inset = textView.textContainerInset;
    builder.padding = NSEdgeInsetsMake(inset.height, inset.width, inset.height, inset.width);
    builder.textObfuscator = textView.isEditable
        ? [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:privacy]
        : [FTSRTextObfuscatingFactory staticTextObfuscator:privacy];
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
