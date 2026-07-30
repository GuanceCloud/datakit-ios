//
//  FTNSSliderRecorder.m
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

@interface FTNSSliderBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) NSArray<NSNumber *> *wireframeIDs;
@property (nonatomic, assign) double minimum;
@property (nonatomic, assign) double maximum;
@property (nonatomic, assign) double value;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL masked;
@property (nonatomic, copy) NSString *accentColor;
@end

@implementation FTNSSliderBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    if (self.wireframeIDs.count != 3 || self.maximum <= self.minimum) {
        return @[];
    }
    CGFloat progress =
        self.masked ? 0.5 : (self.value - self.minimum) / (self.maximum - self.minimum);
    progress = MIN(MAX(progress, 0), 1);
    CGRect track =
        CGRectInset(self.wireframeRect, 2, MAX(0, self.wireframeRect.size.height * 0.4));
    CGRect filled = track;
    filled.size.width *= progress;
    CGFloat thumbSize = MAX(8, MIN(self.wireframeRect.size.height, 16));
    CGRect thumb =
        CGRectMake(CGRectGetMinX(track) + track.size.width * progress - thumbSize * 0.5,
                   CGRectGetMidY(track) - thumbSize * 0.5,
                   thumbSize,
                   thumbSize);
    NSNumber *opacity =
        @(self.enabled ? self.attributes.alpha : self.attributes.alpha * 0.5);
    FTSRShapeWireframe *base = [[FTSRShapeWireframe alloc]
        initWithIdentifier:self.wireframeIDs[0].longLongValue
                     frame:track
                      clip:self.attributes.clip
           backgroundColor:@"#78788033"
              cornerRadius:@(track.size.height * 0.5)
                   opacity:opacity];
    FTSRShapeWireframe *value = [[FTSRShapeWireframe alloc]
        initWithIdentifier:self.wireframeIDs[1].longLongValue
                     frame:filled
                      clip:self.attributes.clip
           backgroundColor:self.accentColor
              cornerRadius:@(track.size.height * 0.5)
                   opacity:opacity];
    FTSRShapeWireframe *knob = [[FTSRShapeWireframe alloc]
        initWithIdentifier:self.wireframeIDs[2].longLongValue
                     frame:thumb
                      clip:self.attributes.clip
           backgroundColor:@"#FFFFFFFF"
              cornerRadius:@(thumbSize * 0.5)
                   opacity:opacity];
    return @[base, value, knob];
}
@end

@implementation FTNSSliderRecorder
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
    if (![view isKindOfClass:NSSlider.class]) {
        return nil;
    }
    NSSlider *slider = (NSSlider *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    FTNSSliderBuilder *builder = [FTNSSliderBuilder new];
    builder.attributes = attributes;
    builder.wireframeIDs =
        [context.viewIDGenerator SRViewIDs:view size:3 nodeRecorder:self];
    builder.minimum = slider.minValue;
    builder.maximum = slider.maxValue;
    builder.value = slider.doubleValue;
    builder.enabled = slider.isEnabled;
    builder.masked = [FTSRTextObfuscatingFactory
        shouldMaskInputElements:
            [attributes resolveTextAndInputPrivacyLevel:context.recorder]];
    builder.accentColor =
        FTSRAppKitHexColor(NSColor.controlAccentColor,
                          slider.effectiveAppearance,
                          @"#007AFFFF");
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
