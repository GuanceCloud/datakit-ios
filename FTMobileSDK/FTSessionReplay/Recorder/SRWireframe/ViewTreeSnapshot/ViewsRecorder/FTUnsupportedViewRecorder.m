//
//  FTUnsupportedViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTUnsupportedViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTUnsupportedViewRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
- (FTSRNodeSemantics *)recorder:(nonnull UIView *)view attributes:(nonnull FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context {
    // Whether it's a controller that shouldn't be collected
    if([context.viewControllerContext isRootView:ViewControllerTypeSafari]||[context.viewControllerContext isRootView:ViewControllerTypeActivity]||[context.viewControllerContext isRootView:ViewControllerTypeSwiftUI]){
        
        // Whether View is invisible
        if (!attributes.isVisible){
            FTInvisibleElement *element = [[FTInvisibleElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
            return element;
        }
        FTUnsupportedViewBuilder *builder = [[FTUnsupportedViewBuilder alloc]init];
        builder.wireframeRect = view.frame;
        builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
        builder.unsupportedClassName = context.viewControllerContext.name?:NSStringFromClass(view.class);
        builder.attributes = attributes;
        FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
        element.nodes = @[builder];
        return element;
    }
    return nil;
}
@end

@implementation FTUnsupportedViewBuilder

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder{
    FTSRPlaceholderWireframe *wireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.wireframeID frame:self.attributes.frame label:self.unsupportedClassName];
    return @[wireframe];
}

@end
