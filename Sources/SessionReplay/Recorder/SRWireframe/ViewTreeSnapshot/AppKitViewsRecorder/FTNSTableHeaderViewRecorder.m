//
//  FTNSTableHeaderViewRecorder.m
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

@interface FTNSTableHeaderBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) NSArray<NSNumber *> *wireframeIDs;
@property (nonatomic, strong) NSArray<NSValue *> *columnFrames;
@property (nonatomic, strong) NSArray<NSString *> *titles;
@property (nonatomic, strong) NSArray<NSNumber *> *fontSizes;
@property (nonatomic, strong) NSArray<NSNumber *> *alignments;
@property (nonatomic, copy) NSString *backgroundColor;
@property (nonatomic, copy) NSString *textColor;
@property (nonatomic, copy) NSString *borderColor;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end

@implementation FTNSTableHeaderBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    NSUInteger count = self.titles.count;
    if (count == 0 ||
        self.wireframeIDs.count != count ||
        self.columnFrames.count != count ||
        self.fontSizes.count != count ||
        self.alignments.count != count) {
        return @[];
    }
    NSMutableArray<FTSRWireframe *> *wireframes =
        [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++) {
        CGRect frame = self.columnFrames[index].rectValue;
        FTSRTextWireframe *column = [[FTSRTextWireframe alloc]
            initWithIdentifier:self.wireframeIDs[index].longLongValue
                         frame:frame];
        column.text = [self.textObfuscator mask:self.titles[index]] ?: @"";
        column.border =
            [[FTSRShapeBorder alloc] initWithColor:self.borderColor width:1];
        column.shapeStyle = [[FTSRShapeStyle alloc]
            initWithBackgroundColor:self.backgroundColor
                       cornerRadius:@0
                             opacity:@(self.attributes.alpha)];
        column.textStyle = [[FTSRTextStyle alloc]
            initWithSize:(int)round(self.fontSizes[index].doubleValue)
                   color:self.textColor
                  family:nil
          truncationMode:
              [FTSRUtils getTextStyleTruncationMode:NSLineBreakByTruncatingTail]];
        FTSRTextPosition *position = [FTSRTextPosition new];
        position.alignment =
            [[FTAlignment alloc]
                initWithTextAlignment:
                    (NSTextAlignment)self.alignments[index].integerValue
                             vertical:@"center"];
        position.padding = [[FTPadding alloc] initWithLeft:8 top:2 right:8 bottom:2];
        column.textPosition = position;
        column.clip =
            [[FTSRContentClip alloc] initWithFrame:frame clip:self.attributes.clip];
        [wireframes addObject:column];
    }
    return wireframes;
}
@end

@implementation FTNSTableHeaderViewRecorder
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
    if (![view isKindOfClass:NSTableHeaderView.class]) {
        return nil;
    }
    NSTableHeaderView *headerView = (NSTableHeaderView *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    NSArray<NSTableColumn *> *tableColumns = headerView.tableView.tableColumns;
    if (tableColumns.count == 0) {
        return [FTInvisibleElement constant];
    }
    NSMutableArray<NSValue *> *columnFrames =
        [NSMutableArray arrayWithCapacity:tableColumns.count];
    NSMutableArray<NSString *> *titles =
        [NSMutableArray arrayWithCapacity:tableColumns.count];
    NSMutableArray<NSNumber *> *fontSizes =
        [NSMutableArray arrayWithCapacity:tableColumns.count];
    NSMutableArray<NSNumber *> *alignments =
        [NSMutableArray arrayWithCapacity:tableColumns.count];
    for (NSUInteger index = 0; index < tableColumns.count; index++) {
        NSTableColumn *tableColumn = tableColumns[index];
        NSRect localFrame = [headerView headerRectOfColumn:index];
        CGFloat localY = headerView.isFlipped
            ? NSMinY(localFrame) - NSMinY(headerView.bounds)
            : NSMaxY(headerView.bounds) - NSMaxY(localFrame);
        CGRect frame =
            CGRectMake(attributes.frame.origin.x +
                           NSMinX(localFrame) - NSMinX(headerView.bounds),
                       attributes.frame.origin.y + localY,
                       NSWidth(localFrame),
                       NSHeight(localFrame));
        [columnFrames addObject:[NSValue valueWithRect:frame]];
        NSCell *headerCell = tableColumn.headerCell;
        [titles addObject:headerCell.stringValue ?: @""];
        [fontSizes addObject:@(headerCell.font.pointSize ?: NSFont.systemFontSize)];
        [alignments addObject:@(headerCell.alignment)];
    }
    FTNSTableHeaderBuilder *builder = [FTNSTableHeaderBuilder new];
    builder.attributes = attributes;
    builder.wireframeIDs =
        [context.viewIDGenerator SRViewIDs:view
                                      size:(int)tableColumns.count
                              nodeRecorder:self];
    builder.columnFrames = columnFrames;
    builder.titles = titles;
    builder.fontSizes = fontSizes;
    builder.alignments = alignments;
    builder.backgroundColor =
        FTSRAppKitHexColor(NSColor.windowBackgroundColor,
                          headerView.effectiveAppearance,
                          @"#F2F2F2FF");
    builder.textColor =
        FTSRAppKitHexColor(NSColor.controlTextColor,
                          headerView.effectiveAppearance,
                          @"#000000FF");
    NSColor *separatorColor = NSColor.gridColor;
    if (@available(macOS 10.14, *)) {
        separatorColor = NSColor.separatorColor;
    }
    builder.borderColor =
        FTSRAppKitHexColor(separatorColor,
                          headerView.effectiveAppearance,
                          @"#0000001F");
    FTTextAndInputPrivacyLevel privacy =
        [attributes resolveTextAndInputPrivacyLevel:context.recorder];
    builder.textObfuscator =
        [FTSRTextObfuscatingFactory staticTextObfuscator:privacy];
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
