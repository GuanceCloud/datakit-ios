//
//  FTNSSegmentedControlRecorder.m
//  SessionReplay AppKit views
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

@interface FTNSSegmentBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) NSArray<NSNumber *> *wireframeIDs;
@property (nonatomic, strong) NSArray<NSString *> *titles;
@property (nonatomic, strong, nullable) NSNumber *selectedIndex;
@property (nonatomic, copy) NSString *accentColor;
@property (nonatomic, copy) NSString *textColor;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end

@implementation FTNSSegmentBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    if (self.titles.count == 0 || self.wireframeIDs.count != self.titles.count + 1) {
        return @[];
    }
    NSMutableArray<FTSRWireframe *> *wireframes = [NSMutableArray array];
    [wireframes addObject:[[FTSRShapeWireframe alloc]
        initWithIdentifier:self.wireframeIDs.firstObject.longLongValue
                     frame:self.wireframeRect
                      clip:self.attributes.clip
           backgroundColor:self.attributes.backgroundColor.hexString ?: @"#7676801F"
              cornerRadius:@6
                   opacity:@(self.attributes.alpha)]];
    CGFloat segmentWidth = self.wireframeRect.size.width / self.titles.count;
    for (NSUInteger index = 0; index < self.titles.count; index++) {
        CGRect frame = CGRectMake(self.wireframeRect.origin.x + segmentWidth * index,
                                  self.wireframeRect.origin.y,
                                  segmentWidth,
                                  self.wireframeRect.size.height);
        FTSRTextWireframe *segment = [[FTSRTextWireframe alloc]
            initWithIdentifier:self.wireframeIDs[index + 1].longLongValue
                         frame:CGRectInset(frame, 1, 1)];
        BOOL selected = self.selectedIndex && self.selectedIndex.integerValue == index;
        segment.text = [self.textObfuscator mask:self.titles[index]] ?: @"";
        segment.shapeStyle = [[FTSRShapeStyle alloc]
            initWithBackgroundColor:selected ? self.accentColor : @"#00000000"
                       cornerRadius:@5
                             opacity:@(self.attributes.alpha)];
        segment.textStyle = [[FTSRTextStyle alloc] initWithSize:13
                                                          color:self.textColor
                                                         family:nil];
        FTSRTextPosition *position = [FTSRTextPosition new];
        position.alignment =
            [[FTAlignment alloc] initWithTextAlignment:NSTextAlignmentCenter
                                              vertical:@"center"];
        position.padding = [[FTPadding alloc] initWithLeft:2 top:1 right:2 bottom:1];
        segment.textPosition = position;
        segment.clip =
            [[FTSRContentClip alloc] initWithFrame:frame clip:self.attributes.clip];
        [wireframes addObject:segment];
    }
    return wireframes;
}
@end

@implementation FTNSSegmentedControlRecorder
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
    if (![view isKindOfClass:NSSegmentedControl.class]) {
        return nil;
    }
    NSSegmentedControl *control = (NSSegmentedControl *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    NSInteger count = control.segmentCount;
    NSMutableArray<NSString *> *titles =
        [NSMutableArray arrayWithCapacity:MAX(count, 0)];
    for (NSInteger index = 0; index < count; index++) {
        [titles addObject:[control labelForSegment:index] ?: @""];
    }
    FTTextAndInputPrivacyLevel privacy =
        [attributes resolveTextAndInputPrivacyLevel:context.recorder];
    FTNSSegmentBuilder *builder = [FTNSSegmentBuilder new];
    builder.attributes = attributes;
    builder.wireframeIDs =
        [context.viewIDGenerator SRViewIDs:view size:(int)count + 1 nodeRecorder:self];
    builder.titles = titles;
    builder.selectedIndex =
        [FTSRTextObfuscatingFactory shouldMaskInputElements:privacy]
            ? nil
            : @(control.selectedSegment);
    builder.accentColor =
        FTSRAppKitHexColor(NSColor.controlAccentColor,
                          control.effectiveAppearance,
                          @"#007AFFFF");
    builder.textColor =
        FTSRAppKitHexColor(NSColor.controlTextColor,
                          control.effectiveAppearance,
                          @"#000000FF");
    builder.textObfuscator =
        [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:privacy];
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
