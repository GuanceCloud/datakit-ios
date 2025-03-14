//
//  FTUIViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUIViewRecorder.h"
#import "FTViewAttributes.h"
#import "FTSRWireframe.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
#import "FTSystemColors.h"

@implementation FTUIViewRecorder
-(instancetype)init{
    return [self initWithIdentifier:[NSUUID UUID].UUIDString];
}
-(instancetype)initWithIdentifier:(NSString *)identifier{
    return [self initWithIdentifier:identifier semanticsOverride:^FTSRNodeSemantics* _Nullable(UIView *view, FTViewAttributes *attributes) {
        return nil;
    }];
}
-(instancetype)initWithIdentifier:(NSString *)identifier semanticsOverride:(SemanticsOverride)semanticsOverride{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _semanticsOverride = semanticsOverride;
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    FTViewAttributes *attr = attributes;
    if ([context.viewControllerContext isRootView:ViewControllerTypeAlert]){
        attr.backgroundColor = [FTSystemColors systemBackground];
        attr.layerBorderColor = nil;
        attr.layerBorderWidth = 0;
        attr.layerCornerRadius = 16;
        attr.alpha = 1;
        attr.isHidden = NO;
    }
    if(!attr.isVisible){
        return [FTInvisibleElement constant];
    }
    FTSRNodeSemantics *semantics = self.semanticsOverride(view, attr);
    if(semantics){
        return semantics;
    }
    if (attr.hide) {
        FTUIViewBuilder *builder = [[FTUIViewBuilder alloc]init];
        builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
        builder.attributes = attr;
        FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
        element.nodes = @[builder];
        return element;
    }
    if(!attr.hasAnyAppearance){
        FTInvisibleElement *element = [[FTInvisibleElement alloc]init];
        element.subtreeStrategy = NodeSubtreeStrategyRecord;
        return element;
    }
    FTUIViewBuilder *builder = [[FTUIViewBuilder alloc]init];
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    builder.attributes = attr;
    
    FTAmbiguousElement *element = [[FTAmbiguousElement alloc]init];
    element.nodes = @[builder];
    return element;
}
@end
@implementation FTUIViewBuilder
-(NSArray<FTSRWireframe *> *)buildWireframes{
    if(self.attributes.hide){
        FTSRPlaceholderWireframe *placeholderWireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect label:@"Hidden"];
        placeholderWireframe.clip = [[FTSRContentClip alloc]initWithFrame:self.wireframeRect clip:self.attributes.clip];
        return @[placeholderWireframe];
    }
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID attributes:self.attributes];
    return @[wireframe];
}
- (CGRect)wireframeRect {
    return self.attributes.frame;
}

@end

