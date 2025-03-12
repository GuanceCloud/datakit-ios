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
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTUISegmentRecorder
-(instancetype)init{
    return [self initWithIdentifier:[[NSUUID UUID] UUIDString]];
}
-(instancetype)initWithIdentifier:(NSString *)identifier{
    self = [super init];
    if(self){
        _identifier = identifier;
        _textObfuscator = ^id<FTSRTextObfuscatingProtocol> _Nullable(FTViewTreeRecordingContext *context,FTViewAttributes *attributes) {
            return [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
        };
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
    builder.textObfuscator = self.textObfuscator(context,attributes);
    builder.selectedSegmentIndex = [FTSRTextObfuscatingFactory shouldMaskInputElements:[attributes resolveTextAndInputPrivacyLevel:context.recorder]]? nil : @(segment.selectedSegmentIndex);
    if (@available(iOS 13.0, *)) {
        builder.selectedSegmentTintColor = segment.selectedSegmentTintColor;
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
    NSString *color = self.attributes.backgroundColor? [FTSRUtils colorHexString:self.attributes.backgroundColor.CGColor]:[FTSystemColors tertiarySystemFillColorStr];

    FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.wireframeRect clip:self.attributes.clip backgroundColor:color cornerRadius:@(8) opacity:@(self.attributes.alpha)];
    
    CGSize segmentSize = CGSizeMake(self.wireframeRect.size.width/(self.segmentWireframeIDs.count*1.0), self.wireframeRect.size.height*0.96);
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
        segment.border = [[FTSRShapeBorder alloc]initWithColor:isSelected?[FTSystemColors secondarySystemFillColorStr]:[FTSystemColors clearColorStr] width:1];
        segment.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:isSelected?(self.selectedSegmentTintColor?[FTSRUtils colorHexString:self.selectedSegmentTintColor.CGColor]:[FTSystemColors tertiarySystemBackgroundColorStr]):[FTSystemColors clearColorStr] cornerRadius:@(8) opacity:@(self.attributes.alpha)];
        segment.text = [self.textObfuscator mask:self.segmentTitles[i]]?:@"";
        segment.textStyle = [[FTSRTextStyle alloc]initWithSize:14 color:[FTSystemColors labelColorStr] family:[UIFont systemFontOfSize:14].familyName];
        FTSRTextPosition *textPosition = [[FTSRTextPosition alloc]init];
        textPosition.alignment = [[FTAlignment alloc]initWithTextAlignment:NSTextAlignmentCenter vertical:@"center"];
        textPosition.padding = [[FTPadding alloc]initWithLeft:0 top:0 right:0 bottom:0];
        segment.textPosition = textPosition;
        [segments addObject:segment];
    }
    return segments;
}
@end

