//
//  FTNSButtonRecorder.m
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
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRTextObfuscatingFactory.h"
#import "FTSRUtils.h"
#import "FTSRViewID.h"
#import "FTSRWireframe.h"
#import "FTSessionReplayWireframesBuilder.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshot.h"

@interface FTNSButtonBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t backgroundID;
@property (nonatomic, assign) int64_t textID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *textColor;
@property (nonatomic, copy) NSString *fillColor;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL masked;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end

@implementation FTNSButtonBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    NSString *fill =
        (!self.masked && self.selected) ? self.fillColor : self.attributes.backgroundColor.hexString;
    if (!fill) {
        fill = @"#7676801F";
    }
    FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]
        initWithIdentifier:self.backgroundID
                     frame:self.wireframeRect
                      clip:self.attributes.clip
           backgroundColor:fill
              cornerRadius:@(MAX(self.attributes.layerCornerRadius, 4))
                   opacity:@(self.enabled
                                 ? self.attributes.alpha
                                 : self.attributes.alpha * 0.5)];
    FTSRTextWireframe *text =
        [[FTSRTextWireframe alloc] initWithIdentifier:self.textID frame:self.wireframeRect];
    text.text = [self.textObfuscator mask:self.title] ?: @"";
    text.shapeStyle = [[FTSRShapeStyle alloc] initWithBackgroundColor:@"#00000000"
                                                         cornerRadius:@0
                                                               opacity:@(self.attributes.alpha)];
    text.textStyle = [[FTSRTextStyle alloc] initWithSize:(int)round(self.fontSize)
                                                   color:self.textColor
                                                  family:nil];
    FTSRTextPosition *position = [FTSRTextPosition new];
    position.alignment = [[FTAlignment alloc] initWithTextAlignment:NSTextAlignmentCenter
                                                           vertical:@"center"];
    position.padding = [[FTPadding alloc] initWithLeft:4 top:2 right:4 bottom:2];
    text.textPosition = position;
    text.clip =
        [[FTSRContentClip alloc] initWithFrame:self.wireframeRect clip:self.attributes.clip];
    return @[background, text];
}
@end

@implementation FTNSButtonRecorder
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
    if (![view isKindOfClass:NSButton.class]) {
        return nil;
    }
    NSButton *button = (NSButton *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    NSArray<NSNumber *> *identifiers =
        [context.viewIDGenerator SRViewIDs:view size:2 nodeRecorder:self];
    FTTextAndInputPrivacyLevel privacy =
        [attributes resolveTextAndInputPrivacyLevel:context.recorder];
    FTNSButtonBuilder *builder = [FTNSButtonBuilder new];
    builder.backgroundID = identifiers[0].longLongValue;
    builder.textID = identifiers[1].longLongValue;
    builder.attributes = attributes;
    builder.title = button.title ?: @"";
    builder.fontSize = button.font.pointSize ?: NSFont.systemFontSize;
    builder.textColor =
        FTSRAppKitHexColor(NSColor.controlTextColor,
                          button.effectiveAppearance,
                          @"#000000FF");
    builder.fillColor =
        FTSRAppKitHexColor(NSColor.controlAccentColor,
                          button.effectiveAppearance,
                          @"#007AFFFF");
    builder.selected = button.state == NSControlStateValueOn;
    builder.enabled = button.isEnabled;
    builder.masked = [FTSRTextObfuscatingFactory shouldMaskInputElements:privacy];
    builder.textObfuscator =
        [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:privacy];
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
