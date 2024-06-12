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

@implementation FTUIViewRecorder
-(NSArray<id<FTSRWireframesBuilder>> *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTRecorderContext *)context{
    return nil;
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
