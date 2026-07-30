//
//  FTNSTextFieldRecorder.m
//  SessionReplay AppKit views
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
