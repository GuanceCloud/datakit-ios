//
//  FTNSSwitchRecorder.m
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

@interface FTNSSwitchBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) NSArray<NSNumber *> *wireframeIDs;
@property (nonatomic, assign) BOOL on;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL masked;
@property (nonatomic, copy) NSString *onColor;
@property (nonatomic, copy) NSString *offColor;
@property (nonatomic, copy) NSString *thumbColor;
@property (nonatomic, copy) NSString *thumbBorderColor;
@end

@implementation FTNSSwitchBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    if (self.wireframeIDs.count != 3) {
        return @[];
    }
    NSMutableArray<FTSRWireframe *> *wireframes = [NSMutableArray array];
    if (self.attributes.hasAnyAppearance) {
        [wireframes addObject:[[FTSRShapeWireframe alloc]
            initWithIdentifier:self.wireframeIDs[0].longLongValue
                    attributes:self.attributes]];
    }
    NSNumber *opacity =
        @(self.enabled ? self.attributes.alpha : self.attributes.alpha * 0.5);
    CGRect trackFrame = self.wireframeRect;
    [wireframes addObject:[[FTSRShapeWireframe alloc]
        initWithIdentifier:self.wireframeIDs[1].longLongValue
                     frame:trackFrame
                      clip:self.attributes.clip
           backgroundColor:self.masked
                               ? self.offColor
                               : (self.on ? self.onColor : self.offColor)
              cornerRadius:@(trackFrame.size.height * 0.5)
                   opacity:opacity]];
    if (!self.masked) {
        CGFloat inset = 2;
        CGFloat thumbSize =
            MAX(0, MIN(trackFrame.size.height - inset * 2,
                       trackFrame.size.width - inset * 2));
        CGFloat thumbX = self.on
            ? CGRectGetMaxX(trackFrame) - inset - thumbSize
            : CGRectGetMinX(trackFrame) + inset;
        CGRect thumbFrame = CGRectMake(thumbX,
                                       CGRectGetMidY(trackFrame) - thumbSize * 0.5,
                                       thumbSize,
                                       thumbSize);
        FTSRShapeWireframe *thumb = [[FTSRShapeWireframe alloc]
            initWithIdentifier:self.wireframeIDs[2].longLongValue
                         frame:thumbFrame
                          clip:self.attributes.clip
               backgroundColor:self.thumbColor
                  cornerRadius:@(thumbSize * 0.5)
                       opacity:@(self.attributes.alpha)];
        thumb.border =
            [[FTSRShapeBorder alloc] initWithColor:self.thumbBorderColor width:1];
        [wireframes addObject:thumb];
    }
    return wireframes;
}
@end

@implementation FTNSSwitchRecorder
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
    if (@available(macOS 10.15, *)) {
        if (![view isKindOfClass:NSSwitch.class]) {
            return nil;
        }
        NSSwitch *toggle = (NSSwitch *)view;
        if (!attributes.isVisible) {
            return [FTInvisibleElement constant];
        }
        FTNSSwitchBuilder *builder = [FTNSSwitchBuilder new];
        builder.attributes = attributes;
        builder.wireframeIDs =
            [context.viewIDGenerator SRViewIDs:view size:3 nodeRecorder:self];
        builder.on = toggle.state == NSControlStateValueOn;
        builder.enabled = toggle.isEnabled;
        builder.masked = [FTSRTextObfuscatingFactory
            shouldMaskInputElements:
                [attributes resolveTextAndInputPrivacyLevel:context.recorder]];
        builder.onColor =
            FTSRAppKitHexColor(NSColor.controlAccentColor,
                              toggle.effectiveAppearance,
                              @"#34C759FF");
        builder.offColor =
            FTSRAppKitHexColor(NSColor.controlColor,
                              toggle.effectiveAppearance,
                              @"#78788033");
        builder.thumbColor =
            FTSRAppKitHexColor(NSColor.whiteColor,
                              toggle.effectiveAppearance,
                              @"#FFFFFFFF");
        NSColor *separatorColor = NSColor.gridColor;
        if (@available(macOS 10.14, *)) {
            separatorColor = NSColor.separatorColor;
        }
        builder.thumbBorderColor =
            FTSRAppKitHexColor(separatorColor,
                              toggle.effectiveAppearance,
                              @"#0000001F");
        FTSpecificElement *element = [[FTSpecificElement alloc]
            initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
        element.nodes = @[builder];
        return element;
    }
    return nil;
}
@end

#endif
