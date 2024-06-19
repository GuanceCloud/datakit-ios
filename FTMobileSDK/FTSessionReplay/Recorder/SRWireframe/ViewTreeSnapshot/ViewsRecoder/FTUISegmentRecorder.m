//
//  FTUISegmentRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/29.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUISegmentRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTUISegmentRecorder
-(instancetype)init{
    return [self initWithTextObfuscator:^id<FTSRTextObfuscatingProtocol> _Nullable(FTViewTreeRecordingContext *context) {
        return [context.recorder.privacy inputAndOptionTextObfuscator];
    }];
}
-(instancetype)initWithTextObfuscator:(FTTextObfuscator)textObfuscator{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _textObfuscator = textObfuscator;
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UISegmentedControl.class]){
        return nil;
    }
    if (!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UISegmentedControl *segment = (UISegmentedControl *)view;
    NSArray *ids = [context.viewIDGenerator SRViewIDs:segment size:(int)segment.numberOfSegments+1 nodeRecorder:self];
    FTUISegmentBuilder *builder = [[FTUISegmentBuilder alloc]init];
    builder.attributes = attributes;
    builder.wireframeRect = attributes.frame;
    builder.textObfuscator = self.textObfuscator(context);
    builder.selectedSegmentIndex = @(segment.selectedSegmentIndex);
    if (@available(iOS 13.0, *)) {
        builder.selectedSegmentTintColor = segment.selectedSegmentTintColor.CGColor;
    }
    builder.backgroundWireframeID = [ids[0] intValue];
    builder.segmentWireframeIDs = [ids subarrayWithRange:NSMakeRange(1, ids.count-1)];
    NSMutableArray *titles = [NSMutableArray new];
    for (int i=0; i<segment.numberOfSegments; i++) {
        [titles addObject:[segment titleForSegmentAtIndex:i]];
    }
    builder.segmentTitles = titles;
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

@implementation FTUISegmentBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    if(self.segmentWireframeIDs.count <= 0 || self.segmentWireframeIDs.count != self.segmentTitles.count || self.selectedSegmentIndex < 0){
        return nil;
    }
    FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.wireframeRect];
    NSString *color = self.attributes.backgroundColor? [FTSRUtils colorHexString:self.attributes.backgroundColor]:[FTSystemColors tertiarySystemFillColor];
    background.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:color cornerRadius:@(8) opacity:@(self.attributes.alpha)];
    
    CGSize segmentSize = CGSizeMake(self.wireframeRect.size.width/self.segmentWireframeIDs.count, self.wireframeRect.size.height*0.96);
    CGRect dividedRect = self.wireframeRect;
    NSMutableArray *segments = [[NSMutableArray alloc]initWithArray:@[background]];
    for (int i=0;i<self.segmentWireframeIDs.count;i++) {
        CGRect slice, remainder;
        CGRectDivide(dividedRect, &slice, &remainder, segmentSize.width,CGRectMinXEdge);
        dividedRect = remainder;
        slice = CGRectInset(slice, 2, 2);
        FTSRTextWireframe *segment = [[FTSRTextWireframe alloc]initWithIdentifier:[self.segmentWireframeIDs[i] intValue] frame:slice];
        BOOL isSelected = NO;
        if (self.selectedSegmentIndex != nil){
            isSelected = [self.selectedSegmentIndex intValue] == i;
        }
        segment.border = [[FTSRShapeBorder alloc]initWithColor:isSelected?[FTSystemColors tertiarySystemBackgroundColor]:[FTSystemColors clearColor] width:1];
        segment.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:isSelected?(self.selectedSegmentTintColor?[FTSRUtils colorHexString:self.selectedSegmentTintColor]:[FTSystemColors tertiarySystemBackgroundColor]):[FTSystemColors clearColor] cornerRadius:@(8) opacity:@(self.attributes.alpha)];
        segment.text = [self.textObfuscator mask:self.segmentTitles[i]]?:@"";
        segment.textStyle = [[FTSRTextStyle alloc]initWithSize:14 color:[FTSystemColors labelColor] family:[UIFont systemFontOfSize:14].familyName];
        FTSRTextPosition *textPosition = [[FTSRTextPosition alloc]init];
        textPosition.alignment = [[FTAlignment alloc]initWithTextAlignment:NSTextAlignmentCenter horizontal:@"center"];
        textPosition.padding = [[FTSRContentClip alloc]initWithLeft:0 top:0 right:0 bottom:0];
        segment.textPosition = textPosition;
        [segments addObject:segment];
    }
    return segments;
}
@end

