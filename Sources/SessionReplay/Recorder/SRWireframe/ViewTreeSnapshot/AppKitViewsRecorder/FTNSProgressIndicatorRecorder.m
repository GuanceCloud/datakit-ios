//
//  FTNSProgressIndicatorRecorder.m
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
#import "FTSRViewID.h"
#import "FTSRWireframe.h"
#import "FTSessionReplayWireframesBuilder.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshot.h"

@interface FTNSProgressBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) NSArray<NSNumber *> *wireframeIDs;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) BOOL indeterminate;
@property (nonatomic, copy) NSString *accentColor;
@end

@implementation FTNSProgressBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    if (self.wireframeIDs.count != 2) {
        return @[];
    }
    FTSRShapeWireframe *track = [[FTSRShapeWireframe alloc]
        initWithIdentifier:self.wireframeIDs[0].longLongValue
                     frame:self.wireframeRect
                      clip:self.attributes.clip
           backgroundColor:@"#78788033"
              cornerRadius:@(self.wireframeRect.size.height * 0.5)
                   opacity:@(self.attributes.alpha)];
    CGFloat progress = self.indeterminate ? 0.35 : MIN(MAX(self.progress, 0), 1);
    CGRect valueFrame = self.wireframeRect;
    valueFrame.size.width *= progress;
    FTSRShapeWireframe *value = [[FTSRShapeWireframe alloc]
        initWithIdentifier:self.wireframeIDs[1].longLongValue
                     frame:valueFrame
                      clip:self.attributes.clip
           backgroundColor:self.accentColor
              cornerRadius:@(self.wireframeRect.size.height * 0.5)
                   opacity:@(self.attributes.alpha)];
    return @[track, value];
}
@end

@implementation FTNSProgressIndicatorRecorder
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
    if (![view isKindOfClass:NSProgressIndicator.class]) {
        return nil;
    }
    NSProgressIndicator *indicator = (NSProgressIndicator *)view;
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    FTNSProgressBuilder *builder = [FTNSProgressBuilder new];
    builder.attributes = attributes;
    builder.wireframeIDs =
        [context.viewIDGenerator SRViewIDs:view size:2 nodeRecorder:self];
    builder.indeterminate = indicator.isIndeterminate;
    builder.progress = indicator.maxValue > indicator.minValue
        ? (indicator.doubleValue - indicator.minValue) /
              (indicator.maxValue - indicator.minValue)
        : 0;
    builder.accentColor =
        FTSRAppKitHexColor(NSColor.controlAccentColor,
                          indicator.effectiveAppearance,
                          @"#007AFFFF");
    FTSpecificElement *element = [[FTSpecificElement alloc]
        initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

#endif
