//
//  FTNSTextFieldRecorder.m
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

@implementation FTNSTextFieldRecorder
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
    if (![view isKindOfClass:NSTextField.class]) {
        return nil;
    }
    NSTextField *textField = (NSTextField *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    NSString *text = textField.stringValue ?: @"";
    BOOL isPlaceholder = text.length == 0 && textField.placeholderString.length > 0;
    if (isPlaceholder) {
        text = textField.placeholderString;
    }
    BOOL isInput = textField.isEditable;
    BOOL isSensitive = [textField isKindOfClass:NSSecureTextField.class];
    FTTextAndInputPrivacyLevel privacy =
        [attributes resolveTextAndInputPrivacyLevel:context.recorder];
    id<FTSRTextObfuscatingProtocol> obfuscator = nil;
    if (isPlaceholder) {
        obfuscator = [FTSRTextObfuscatingFactory hintTextObfuscator:privacy];
    } else if (isSensitive) {
        obfuscator = [FTSRTextObfuscatingFactory sensitiveTextObfuscator:privacy];
    } else if (isInput) {
        obfuscator = [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:privacy];
    } else {
        obfuscator = [FTSRTextObfuscatingFactory staticTextObfuscator:privacy];
    }
    FTNSTextBuilder *builder = [FTNSTextBuilder new];
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    builder.attributes = attributes;
    builder.text = text;
    builder.fontSize = textField.font.pointSize ?: NSFont.systemFontSize;
    builder.fontFamily = textField.font.familyName;
    builder.textColor =
        FTSRAppKitHexColor(textField.textColor, textField.effectiveAppearance, @"#000000FF");
    builder.backgroundColor = textField.drawsBackground
        ? FTSRAppKitHexColor(textField.backgroundColor,
                            textField.effectiveAppearance,
                            @"#FFFFFFFF")
        : nil;
    builder.alignment = textField.alignment;
    builder.lineBreakMode = textField.lineBreakMode;
    builder.padding = NSEdgeInsetsMake(2, 4, 2, 4);
    builder.textObfuscator = obfuscator;
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
