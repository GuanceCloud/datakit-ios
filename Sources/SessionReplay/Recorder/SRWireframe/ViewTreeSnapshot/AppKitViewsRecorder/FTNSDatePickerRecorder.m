//
//  FTNSDatePickerRecorder.m
//  SessionReplay AppKit views
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import "FTAppKitViewRecorders.h"
#import <AppKit/AppKit.h>
#import "FTAppKitRecorderSupport.h"
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRTextObfuscatingFactory.h"
#import "FTSRViewID.h"
#import "FTSRWireframe.h"
#import "FTSessionReplayWireframesBuilder.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshot.h"

static const int FTSRDatePickerWireframeCount = 54;

static FTSRShapeWireframe *FTSRDatePickerShape(int64_t identifier,
                                               CGRect frame,
                                               CGRect clip,
                                               NSString *backgroundColor,
                                               NSString *borderColor,
                                               CGFloat cornerRadius,
                                               CGFloat opacity) {
    FTSRShapeWireframe *shape =
        [[FTSRShapeWireframe alloc] initWithIdentifier:identifier
                                                frame:frame
                                                 clip:clip
                                      backgroundColor:backgroundColor
                                         cornerRadius:@(cornerRadius)
                                              opacity:@(opacity)];
    shape.border = [[FTSRShapeBorder alloc] initWithColor:borderColor width:1];
    return shape;
}

static FTSRTextWireframe *FTSRDatePickerText(int64_t identifier,
                                             CGRect frame,
                                             CGRect clip,
                                             NSString *text,
                                             NSString *textColor,
                                             NSString *backgroundColor,
                                             CGFloat fontSize,
                                             CGFloat cornerRadius,
                                             CGFloat opacity,
                                             NSTextAlignment alignment,
                                             id<FTSRTextObfuscatingProtocol> obfuscator) {
    FTSRTextWireframe *wireframe =
        [[FTSRTextWireframe alloc] initWithIdentifier:identifier frame:frame];
    wireframe.text = [obfuscator mask:text ?: @""] ?: @"";
    wireframe.shapeStyle =
        [[FTSRShapeStyle alloc] initWithBackgroundColor:backgroundColor
                                          cornerRadius:@(cornerRadius)
                                                opacity:@(opacity)];
    wireframe.textStyle =
        [[FTSRTextStyle alloc] initWithSize:(int)round(fontSize)
                                     color:textColor
                                    family:nil];
    FTSRTextPosition *position = [FTSRTextPosition new];
    position.alignment =
        [[FTAlignment alloc] initWithTextAlignment:alignment vertical:@"center"];
    position.padding = [[FTPadding alloc] initWithLeft:2 top:0 right:2 bottom:0];
    wireframe.textPosition = position;
    wireframe.clip = [[FTSRContentClip alloc] initWithFrame:frame clip:clip];
    return wireframe;
}

static NSString *FTSRDatePickerFormattedValue(NSDate *date,
                                               NSDatePickerElementFlags elements,
                                               NSCalendar *calendar,
                                               NSLocale *locale,
                                               NSTimeZone *timeZone) {
    NSMutableString *template = [NSMutableString string];
    BOOL showsDay =
        (elements & NSDatePickerElementFlagYearMonthDay) ==
        NSDatePickerElementFlagYearMonthDay;
    BOOL showsMonth =
        (elements & NSDatePickerElementFlagYearMonth) ==
        NSDatePickerElementFlagYearMonth;
    BOOL showsSeconds =
        (elements & NSDatePickerElementFlagHourMinuteSecond) ==
        NSDatePickerElementFlagHourMinuteSecond;
    BOOL showsTime =
        (elements & NSDatePickerElementFlagHourMinute) ==
        NSDatePickerElementFlagHourMinute;
    if (showsDay) {
        [template appendString:@"yMd"];
    } else if (showsMonth) {
        [template appendString:@"yM"];
    }
    if (showsSeconds) {
        [template appendString:@"Hms"];
    } else if (showsTime) {
        [template appendString:@"Hm"];
    }
    if ((elements & NSDatePickerElementFlagTimeZone) != 0) {
        [template appendString:@"z"];
    }
    if (template.length == 0) {
        [template appendString:@"yMd"];
    }
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.calendar = calendar;
    formatter.locale = locale;
    formatter.timeZone = timeZone;
    [formatter setLocalizedDateFormatFromTemplate:template];
    return [formatter stringFromDate:date] ?: @"";
}

@interface FTNSDatePickerBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) NSArray<NSNumber *> *wireframeIDs;
@property (nonatomic, assign) NSDatePickerStyle style;
@property (nonatomic, assign) NSDatePickerElementFlags elements;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSCalendar *calendar;
@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, strong) NSTimeZone *timeZone;
@property (nonatomic, copy) NSString *backgroundColor;
@property (nonatomic, copy) NSString *textColor;
@property (nonatomic, copy) NSString *secondaryTextColor;
@property (nonatomic, copy) NSString *selectedTextColor;
@property (nonatomic, copy) NSString *accentColor;
@property (nonatomic, copy) NSString *borderColor;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL maskSelection;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> valueObfuscator;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> staticObfuscator;
@end

@implementation FTNSDatePickerBuilder

- (CGRect)wireframeRect {
    return self.attributes.frame;
}

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:
    (FTSessionReplayWireframesBuilder *)builder {
    if (self.wireframeIDs.count < FTSRDatePickerWireframeCount) {
        return @[];
    }
    if (self.style == NSDatePickerStyleClockAndCalendar) {
        return [self graphicalCalendarWireframes];
    }
    return [self textFieldWireframes];
}

- (NSArray<FTSRWireframe *> *)textFieldWireframes {
    CGRect frame = self.wireframeRect;
    CGFloat opacity =
        self.enabled ? self.attributes.alpha : self.attributes.alpha * 0.5;
    NSMutableArray<FTSRWireframe *> *wireframes = [NSMutableArray array];
    [wireframes addObject:
        FTSRDatePickerShape(self.wireframeIDs[0].longLongValue,
                            frame,
                            self.attributes.clip,
                            self.backgroundColor,
                            self.borderColor,
                            MAX(self.attributes.layerCornerRadius, 4),
                            opacity)];

    CGFloat stepperWidth =
        self.style == NSDatePickerStyleTextFieldAndStepper
            ? MIN(22, CGRectGetWidth(frame) * 0.25)
            : 0;
    CGRect valueFrame = CGRectMake(CGRectGetMinX(frame) + 4,
                                   CGRectGetMinY(frame),
                                   MAX(0, CGRectGetWidth(frame) - stepperWidth - 8),
                                   CGRectGetHeight(frame));
    NSString *value =
        FTSRDatePickerFormattedValue(self.date,
                                     self.elements,
                                     self.calendar,
                                     self.locale,
                                     self.timeZone);
    [wireframes addObject:
        FTSRDatePickerText(self.wireframeIDs[1].longLongValue,
                           valueFrame,
                           self.attributes.clip,
                           value,
                           self.textColor,
                           @"#00000000",
                           self.fontSize,
                           0,
                           opacity,
                           NSTextAlignmentLeft,
                           self.valueObfuscator)];

    if (stepperWidth > 0) {
        CGFloat halfHeight = CGRectGetHeight(frame) * 0.5;
        CGRect upFrame = CGRectMake(CGRectGetMaxX(frame) - stepperWidth,
                                    CGRectGetMinY(frame),
                                    stepperWidth,
                                    halfHeight);
        CGRect downFrame = CGRectMake(CGRectGetMinX(upFrame),
                                      CGRectGetMaxY(upFrame),
                                      stepperWidth,
                                      CGRectGetHeight(frame) - halfHeight);
        [wireframes addObject:
            FTSRDatePickerText(self.wireframeIDs[2].longLongValue,
                               upFrame,
                               self.attributes.clip,
                               @"▲",
                               self.secondaryTextColor,
                               @"#00000000",
                               MAX(8, self.fontSize - 2),
                               0,
                               opacity,
                               NSTextAlignmentCenter,
                               self.staticObfuscator)];
        [wireframes addObject:
            FTSRDatePickerText(self.wireframeIDs[3].longLongValue,
                               downFrame,
                               self.attributes.clip,
                               @"▼",
                               self.secondaryTextColor,
                               @"#00000000",
                               MAX(8, self.fontSize - 2),
                               0,
                               opacity,
                               NSTextAlignmentCenter,
                               self.staticObfuscator)];
    }
    return wireframes;
}

- (NSArray<FTSRWireframe *> *)graphicalCalendarWireframes {
    CGRect frame = self.wireframeRect;
    CGFloat opacity =
        self.enabled ? self.attributes.alpha : self.attributes.alpha * 0.5;
    NSMutableArray<FTSRWireframe *> *wireframes =
        [NSMutableArray arrayWithCapacity:FTSRDatePickerWireframeCount];
    [wireframes addObject:
        FTSRDatePickerShape(self.wireframeIDs[0].longLongValue,
                            frame,
                            self.attributes.clip,
                            self.backgroundColor,
                            self.borderColor,
                            MAX(self.attributes.layerCornerRadius, 4),
                            opacity)];

    CGFloat inset = MIN(8, CGRectGetWidth(frame) * 0.05);
    CGFloat headerHeight = MIN(26, CGRectGetHeight(frame) * 0.18);
    CGFloat weekdayHeight = MIN(18, CGRectGetHeight(frame) * 0.13);
    CGFloat contentWidth = MAX(0, CGRectGetWidth(frame) - inset * 2);
    CGFloat cellWidth = contentWidth / 7.0;
    CGFloat gridHeight =
        MAX(0, CGRectGetHeight(frame) - inset * 2 - headerHeight - weekdayHeight);
    CGFloat cellHeight = gridHeight / 6.0;
    CGFloat headerY = CGRectGetMinY(frame) + inset;

    NSDateFormatter *monthFormatter = [NSDateFormatter new];
    monthFormatter.calendar = self.calendar;
    monthFormatter.locale = self.locale;
    monthFormatter.timeZone = self.timeZone;
    [monthFormatter setLocalizedDateFormatFromTemplate:@"MMM yyyy"];
    NSString *monthTitle = [monthFormatter stringFromDate:self.date] ?: @"";
    CGRect monthFrame = CGRectMake(CGRectGetMinX(frame) + inset,
                                   headerY,
                                   MAX(0, contentWidth - 48),
                                   headerHeight);
    [wireframes addObject:
        FTSRDatePickerText(self.wireframeIDs[1].longLongValue,
                           monthFrame,
                           self.attributes.clip,
                           monthTitle,
                           self.textColor,
                           @"#00000000",
                           MAX(self.fontSize, 12),
                           0,
                           opacity,
                           NSTextAlignmentLeft,
                           self.valueObfuscator)];

    NSArray<NSString *> *navigationSymbols = @[@"◀", @"●", @"▶"];
    for (NSUInteger index = 0; index < navigationSymbols.count; index++) {
        CGRect navigationFrame =
            CGRectMake(CGRectGetMaxX(frame) - inset - 48 + index * 16,
                       headerY,
                       16,
                       headerHeight);
        [wireframes addObject:
            FTSRDatePickerText(self.wireframeIDs[index + 2].longLongValue,
                               navigationFrame,
                               self.attributes.clip,
                               navigationSymbols[index],
                               self.secondaryTextColor,
                               @"#00000000",
                               MAX(8, self.fontSize - 2),
                               0,
                               opacity,
                               NSTextAlignmentCenter,
                               self.staticObfuscator)];
    }

    NSDateFormatter *weekdayFormatter = [NSDateFormatter new];
    weekdayFormatter.calendar = self.calendar;
    weekdayFormatter.locale = self.locale;
    weekdayFormatter.timeZone = self.timeZone;
    NSArray<NSString *> *weekdaySymbols =
        weekdayFormatter.veryShortStandaloneWeekdaySymbols;
    if (weekdaySymbols.count != 7) {
        weekdaySymbols = weekdayFormatter.shortWeekdaySymbols;
    }
    NSUInteger firstWeekday = MAX((NSUInteger)1, self.calendar.firstWeekday);
    CGFloat weekdayY = headerY + headerHeight;
    for (NSUInteger column = 0; column < 7; column++) {
        NSUInteger symbolIndex = (firstWeekday - 1 + column) % 7;
        NSString *symbol =
            symbolIndex < weekdaySymbols.count ? weekdaySymbols[symbolIndex] : @"";
        CGRect weekdayFrame =
            CGRectMake(CGRectGetMinX(frame) + inset + column * cellWidth,
                       weekdayY,
                       cellWidth,
                       weekdayHeight);
        [wireframes addObject:
            FTSRDatePickerText(self.wireframeIDs[column + 5].longLongValue,
                               weekdayFrame,
                               self.attributes.clip,
                               symbol,
                               self.secondaryTextColor,
                               @"#00000000",
                               MAX(8, self.fontSize - 2),
                               0,
                               opacity,
                               NSTextAlignmentCenter,
                               self.staticObfuscator)];
    }

    NSDateComponents *monthComponents =
        [self.calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth)
                         fromDate:self.date];
    monthComponents.day = 1;
    NSDate *firstDateOfMonth =
        [self.calendar dateFromComponents:monthComponents] ?: self.date;
    NSInteger firstDateWeekday =
        [self.calendar component:NSCalendarUnitWeekday
                        fromDate:firstDateOfMonth];
    NSInteger leadingDayCount =
        (firstDateWeekday - (NSInteger)firstWeekday + 7) % 7;
    NSDate *firstVisibleDate =
        [self.calendar dateByAddingUnit:NSCalendarUnitDay
                                 value:-leadingDayCount
                                toDate:firstDateOfMonth
                               options:0] ?: firstDateOfMonth;
    NSDateComponents *selectedComponents =
        [self.calendar components:(NSCalendarUnitYear |
                                   NSCalendarUnitMonth |
                                   NSCalendarUnitDay)
                         fromDate:self.date];
    NSDateFormatter *dayFormatter = [NSDateFormatter new];
    dayFormatter.calendar = self.calendar;
    dayFormatter.locale = self.locale;
    dayFormatter.timeZone = self.timeZone;
    dayFormatter.dateFormat = @"d";
    CGFloat gridY = weekdayY + weekdayHeight;
    for (NSUInteger index = 0; index < 42; index++) {
        NSDate *cellDate =
            [self.calendar dateByAddingUnit:NSCalendarUnitDay
                                     value:(NSInteger)index
                                    toDate:firstVisibleDate
                                   options:0] ?: firstVisibleDate;
        NSDateComponents *cellComponents =
            [self.calendar components:(NSCalendarUnitYear |
                                       NSCalendarUnitMonth |
                                       NSCalendarUnitDay)
                             fromDate:cellDate];
        BOOL isSelected =
            cellComponents.year == selectedComponents.year &&
            cellComponents.month == selectedComponents.month &&
            cellComponents.day == selectedComponents.day;
        BOOL isCurrentMonth =
            cellComponents.year == monthComponents.year &&
            cellComponents.month == monthComponents.month;
        NSUInteger row = index / 7;
        NSUInteger column = index % 7;
        CGRect dayFrame =
            CGRectMake(CGRectGetMinX(frame) + inset + column * cellWidth,
                       gridY + row * cellHeight,
                       cellWidth,
                       cellHeight);
        NSString *backgroundColor =
            isSelected && !self.maskSelection ? self.accentColor : @"#00000000";
        NSString *textColor =
            isSelected && !self.maskSelection
                ? self.selectedTextColor
                : (isCurrentMonth ? self.textColor : self.secondaryTextColor);
        [wireframes addObject:
            FTSRDatePickerText(self.wireframeIDs[index + 12].longLongValue,
                               dayFrame,
                               self.attributes.clip,
                               [dayFormatter stringFromDate:cellDate] ?: @"",
                               textColor,
                               backgroundColor,
                               MAX(8, self.fontSize - 1),
                               MIN(5, cellHeight * 0.25),
                               opacity,
                               NSTextAlignmentCenter,
                               self.valueObfuscator)];
    }
    return wireframes;
}

@end

@implementation FTNSDatePickerRecorder

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
    if (![view isKindOfClass:NSDatePicker.class]) {
        return nil;
    }
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    NSDatePicker *datePicker = (NSDatePicker *)view;
    NSLocale *locale = [datePicker.locale copy] ?: NSLocale.currentLocale;
    NSCalendar *calendar = [datePicker.calendar copy];
    if (!calendar) {
        calendar =
            [[NSCalendar alloc] initWithCalendarIdentifier:
                                    NSCalendarIdentifierGregorian];
    }
    calendar.locale = locale;
    NSTimeZone *timeZone =
        [datePicker.timeZone copy] ?: calendar.timeZone ?: NSTimeZone.localTimeZone;
    calendar.timeZone = timeZone;
    FTTextAndInputPrivacyLevel privacy =
        [attributes resolveTextAndInputPrivacyLevel:context.recorder];

    FTNSDatePickerBuilder *builder = [FTNSDatePickerBuilder new];
    builder.attributes = attributes;
    builder.wireframeIDs =
        [context.viewIDGenerator SRViewIDs:view
                                      size:FTSRDatePickerWireframeCount
                              nodeRecorder:self];
    builder.style = datePicker.datePickerStyle;
    builder.elements = datePicker.datePickerElements;
    builder.date = [datePicker.dateValue copy];
    builder.calendar = calendar;
    builder.locale = locale;
    builder.timeZone = timeZone;
    builder.backgroundColor =
        FTSRAppKitHexColor(datePicker.backgroundColor ?: NSColor.controlBackgroundColor,
                          datePicker.effectiveAppearance,
                          @"#FFFFFFFF");
    builder.textColor =
        FTSRAppKitHexColor(datePicker.textColor ?: NSColor.controlTextColor,
                          datePicker.effectiveAppearance,
                          @"#000000FF");
    builder.secondaryTextColor =
        FTSRAppKitHexColor(NSColor.secondaryLabelColor,
                          datePicker.effectiveAppearance,
                          @"#00000099");
    builder.selectedTextColor = @"#FFFFFFFF";
    builder.accentColor =
        FTSRAppKitHexColor(NSColor.controlAccentColor,
                          datePicker.effectiveAppearance,
                          @"#007AFFFF");
    builder.borderColor =
        FTSRAppKitHexColor(NSColor.separatorColor,
                          datePicker.effectiveAppearance,
                          @"#00000033");
    builder.fontSize = datePicker.font.pointSize ?: NSFont.systemFontSize;
    builder.enabled = datePicker.isEnabled;
    builder.maskSelection =
        [FTSRTextObfuscatingFactory shouldMaskInputElements:privacy];
    builder.valueObfuscator =
        [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:privacy];
    builder.staticObfuscator =
        [FTSRTextObfuscatingFactory staticTextObfuscator:privacy];

    FTSpecificElement *element =
        [[FTSpecificElement alloc] initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}

@end

#endif
