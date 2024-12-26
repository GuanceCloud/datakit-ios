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
    FTViewTreeRecordingContext *newContext = [context copy];
    if([view.nextResponder isKindOfClass:UIViewController.class]){
        UIViewController *viewController = (UIViewController *)view.nextResponder;
        [newContext.viewControllerContext setParentTypeWithViewController:viewController];
        newContext.viewControllerContext.isRootView = view == viewController.view;
    }else{
        newContext.viewControllerContext.isRootView = NO;
    }
    CGRect frame = [view convertRect:view.bounds toCoordinateSpace:newContext.coordinateSpace];
    if(view.clipsToBounds){
        newContext.clip = CGRectIntersection(frame, newContext.clip);
    }
    FTViewAttributes *attribute = [[FTViewAttributes alloc]initWithView:view frameInRootView:frame clip:newContext.clip];
    FTSRNodeSemantics *semantics = [self nodeSemantics:view context:newContext attribute:attribute];
    if(semantics.nodes.count>0){
        [nodes addObjectsFromArray:semantics.nodes];
    }
    if(semantics.resources.count>0){
        [resource addObjectsFromArray:semantics.resources];
    }
    
    switch (semantics.subtreeStrategy) {
        case NodeSubtreeStrategyRecord:
            for (UIView *subView in view.subviews) {
                [self recordRecursively:nodes resources:resource view:subView context:newContext];
            }
            break;
        case NodeSubtreeStrategyIgnore:
            
            break;
    }
}

- (FTSRNodeSemantics *)nodeSemantics:(UIView *)view context:(FTViewTreeRecordingContext *)context attribute:(FTViewAttributes *)attribute{
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
