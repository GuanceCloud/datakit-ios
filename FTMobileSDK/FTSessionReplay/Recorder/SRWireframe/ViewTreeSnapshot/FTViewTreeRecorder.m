//
//  FTViewTreeRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTViewTreeRecorder.h"
#import "FTViewAttributes.h"
#import "FTSRViewID.h"
#import "FTSRWireframesBuilder.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTViewTreeRecorder
- (void)record:(NSMutableArray *)nodes resources:(NSMutableArray *)resource view:(UIView *)view context:(FTViewTreeRecordingContext *)context{
    [self recordRecursively:nodes resources:resource view:view context:context];
}
- (void)recordRecursively:(NSMutableArray *)nodes resources:(NSMutableArray *)resource view:(UIView *)view context:(FTViewTreeRecordingContext *)context{
    
    if([view.nextResponder isKindOfClass:UIViewController.class]){
        UIViewController *viewController = (UIViewController *)view.nextResponder;
        [context.viewControllerContext setParentTypeWithViewController:viewController];
        context.viewControllerContext.isRootView = view == viewController.view;
    }else{
        context.viewControllerContext.isRootView = NO;
    }
    
    FTSRNodeSemantics *semantics = [self nodeSemantics:view context:context];
    if(semantics.nodes.count>0){
        [nodes addObjectsFromArray:semantics.nodes];
    }
    if(semantics.resources.count>0){
        [resource addObjectsFromArray:semantics.resources];
    }
    
    switch (semantics.subtreeStrategy) {
        case NodeSubtreeStrategyRecord:
            for (UIView *subView in view.subviews) {
                [self recordRecursively:nodes resources:resource view:subView context:context];
            }
            break;
        case NodeSubtreeStrategyIgnore:
            
            break;
    }
}

- (FTSRNodeSemantics *)nodeSemantics:(UIView *)view context:(FTViewTreeRecordingContext *)context{
    FTViewAttributes *attribute = [[FTViewAttributes alloc]initWithFrameInRootView:[view convertRect:view.bounds toCoordinateSpace:context.coordinateSpace] view:view];

    FTSRNodeSemantics *semantics = [FTUnknownElement constant];
    for (id<FTSRWireframesRecorder> recorder in self.nodeRecorders) {
        FTSRNodeSemantics *nextSemantics = [recorder recorder:view attributes:attribute context:context];
        if(nextSemantics){
            if(nextSemantics.importance >= semantics.importance){
                semantics = nextSemantics;
                if(nextSemantics.importance == INT_MAX){
                    break;
                }
            }
        }
    }
    return semantics;
}
@end
