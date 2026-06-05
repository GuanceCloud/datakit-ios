//
//  FTUIProgressViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTUIProgressViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeRecorder.h"
@implementation FTUIProgressViewRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UIProgressView.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UIProgressView *progressView = (UIProgressView *)view;
    NSArray *ids = [context.viewIDGenerator SRViewIDs:progressView size:2 nodeRecorder:self];
    FTUIProgressViewBuilder *builder = [[FTUIProgressViewBuilder alloc]init];
    builder.wireframeRect = attributes.frame;
    builder.attributes = attributes;
    builder.backgroundWireframeID = [ids[0] intValue];
    builder.progressTrackWireframeID = [ids[1] intValue];
    builder.progress = progressView.progress;
    builder.progressTintColor = [FTSRColorSnapshot snapshotWithColor:progressView.progressTintColor?progressView.progressTintColor:progressView.tintColor traitCollection:progressView.traitCollection];
    builder.backgroundColor = [FTSRColorSnapshot snapshotWithColor:progressView.trackTintColor?progressView.trackTintColor:progressView.backgroundColor traitCollection:progressView.traitCollection];
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end
@implementation FTUIProgressViewBuilder
-(NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder{
    if(self.progress<0||self.progress>1){
        return @[];
    }
    FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.wireframeRect clip:self.attributes.clip backgroundColor:self.backgroundColor.hexString?:[FTSystemColors tertiarySystemFillColorStr] cornerRadius:@(self.wireframeRect.size.height/2) opacity:@(1)];
    CGRect slice, remainder;
    CGRectDivide(_wireframeRect, &slice, &remainder, _wireframeRect.size.width*self.progress,CGRectMinXEdge);
    CGRect progressTrackFrame = FTCGRectPutInside(slice, _wireframeRect, HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.progressTrackWireframeID frame:progressTrackFrame clip:self.attributes.clip backgroundColor:self.progressTintColor.hexString cornerRadius:@(self.wireframeRect.size.height/2) opacity:@(self.attributes.alpha)];
    return @[background,wireframe];
    
}
@end
