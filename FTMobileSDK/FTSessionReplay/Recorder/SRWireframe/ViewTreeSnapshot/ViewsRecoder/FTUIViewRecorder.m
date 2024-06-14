//
//  FTUIViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUIViewRecorder.h"
#import "FTSRWireframesBuilder.h"
#import "FTViewAttributes.h"
#import "FTSRWireframe.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
#import "FTSystemColors.h"

@implementation FTUIViewRecorder
-(instancetype)init{
    return [self initWithSemanticsOverride:^id<FTSRNodeSemantics> _Nullable(UIView *view, FTViewAttributes *attributes) {
        return nil;
    }];
}
-(instancetype)initWithSemanticsOverride:(SemanticsOverride)semanticsOverride{
    self = [super init];
    if(self){
        _semanticsOverride = semanticsOverride;
    }
    return self;
}
-(id<FTSRNodeSemantics>)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    FTViewAttributes *attr = attributes;
    if ([context.viewControllerContext isRootView:ViewControllerTypeAlert]){
        attr = [attributes copy];
        attr.backgroundColor = [FTSystemColors systemBackgroundCGColor];
        attr.layerBorderColor = nil;
        attr.layerBorderWidth = 0;
        attr.layerCornerRadius = 16;
        attr.alpha = 1;
        attr.isHidden = NO;
    }
    if(attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    id<FTSRNodeSemantics> semantics = self.semanticsOverride(view, attributes);
    if(semantics){
        return semantics;
    }
    if(!attributes.hasAnyAppearance){
        FTInvisibleElement *element = [[FTInvisibleElement alloc]init];
        element.subtreeStrategy = NodeSubtreeStrategyRecord;
        return element;
    }
    FTUIViewBuilder *builder = [[FTUIViewBuilder alloc]init];
    builder.wireframeID = [context.viewIDGenerator SRViewID:view];
    builder.attributes = attributes;
    
    FTAmbiguousElement *element = [[FTAmbiguousElement alloc]init];
    element.nodes = @[builder];
    return element;
}
@end
@implementation FTUIViewBuilder
-(NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect attributes:self.attributes];
    return @[wireframe];
}
- (CGRect)wireframeRect {
    return self.attributes.frame;
}

@end
@implementation FTUnsupportedBuilder

-(NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRPlaceholderWireframe *wireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect label:self.label];
    return @[wireframe];
}

@end
