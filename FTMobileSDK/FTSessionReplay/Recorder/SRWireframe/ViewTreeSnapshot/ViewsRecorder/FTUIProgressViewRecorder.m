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
    builder.progressTintColor = progressView.progressTintColor.CGColor?progressView.progressTintColor.CGColor:progressView.tintColor.CGColor;
    builder.backgroundColor = progressView.trackTintColor.CGColor?progressView.trackTintColor.CGColor:progressView.backgroundColor.CGColor;
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end
@implementation FTUIProgressViewBuilder
-(NSArray<FTSRWireframe *> *)buildWireframes{
    if(self.progress<0||self.progress>1){
        return @[];
    }
    FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.wireframeRect backgroundColor:self.backgroundColor?[FTSRUtils colorHexString:self.backgroundColor]:[FTSystemColors tertiarySystemFillColor] cornerRadius:@(self.wireframeRect.size.height/2) opacity:@(1)];
    CGRect slice, remainder;
    CGRectDivide(_wireframeRect, &slice, &remainder, _wireframeRect.size.width*self.progress,CGRectMinXEdge);
    CGRect progressTrackFrame = FTCGRectPutInside(slice, _wireframeRect, HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.progressTrackWireframeID frame:progressTrackFrame backgroundColor:[FTSRUtils colorHexString:self.progressTintColor] cornerRadius:@(self.wireframeRect.size.height/2) opacity:@(self.attributes.alpha)];
    return @[background,wireframe];
    
}
@end
