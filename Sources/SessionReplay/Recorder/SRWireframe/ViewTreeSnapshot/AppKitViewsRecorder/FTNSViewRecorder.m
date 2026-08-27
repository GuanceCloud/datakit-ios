//
//  FTNSViewRecorder.m
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
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSRViewID.h"
#import "FTSRWireframe.h"
#import "FTSessionReplayWireframesBuilder.h"
#import "FTViewAttributes.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeSnapshot.h"

@interface FTNSViewBuilder : NSObject <FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@end

@implementation FTNSViewBuilder
- (CGRect)wireframeRect {
    return self.attributes.frame;
}
- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    if (self.attributes.hide) {
        FTSRPlaceholderWireframe *placeholder = [[FTSRPlaceholderWireframe alloc]
            initWithIdentifier:self.wireframeID
                         frame:self.wireframeRect
                         label:@"Hidden"];
        placeholder.clip = [[FTSRContentClip alloc] initWithFrame:self.wireframeRect
                                                             clip:self.attributes.clip];
        return @[placeholder];
    }
    return @[[[FTSRShapeWireframe alloc] initWithIdentifier:self.wireframeID
                                                 attributes:self.attributes]];
}
@end

@implementation FTNSViewRecorder
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
    if (!attributes.isVisible) {
        return [FTInvisibleElement constant];
    }
    BOOL isViewportRoot = view == context.coordinateSpace;
    FTViewAttributes *recordedAttributes = attributes;
    if (isViewportRoot && !attributes.hide && attributes.backgroundColor.alpha <= 0) {
        recordedAttributes = [attributes copy];
        NSColor *backgroundColor = view.window.backgroundColor ?: NSColor.windowBackgroundColor;
        recordedAttributes.backgroundColor =
            [FTSRColorSnapshot snapshotWithColor:backgroundColor
                                traitCollection:view.effectiveAppearance];
    }
    if (!recordedAttributes.hasAnyAppearance && !recordedAttributes.hide) {
        FTInvisibleElement *element = [FTInvisibleElement new];
        element.subtreeStrategy = NodeSubtreeStrategyRecord;
        return element;
    }
    FTNSViewBuilder *builder = [FTNSViewBuilder new];
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    builder.attributes = recordedAttributes;
    if (recordedAttributes.hide) {
        FTSpecificElement *element = [[FTSpecificElement alloc]
            initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
        element.nodes = @[builder];
        return element;
    }
    FTAmbiguousElement *element = [FTAmbiguousElement new];
    element.nodes = @[builder];
    return element;
}
@end

#endif
