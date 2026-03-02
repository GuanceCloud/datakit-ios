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
#import "FTSRNodeWireframesBuilder.h"
#import "FTViewTreeRecordingContext.h"
#import "UIView+FTSRPrivacy.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"
@implementation FTViewTreeRecorder
- (void)record:(NSMutableArray *)nodes resources:(NSMutableArray *)resource view:(UIView *)view context:(FTViewTreeRecordingContext *)context{
    [self recordRecursively:nodes resources:resource view:view context:context overrides:view.sessionReplayPrivacyOverrides];
}
- (void)recordRecursively:(NSMutableArray *)nodes resources:(NSMutableArray *)resource view:(UIView *)view context:(FTViewTreeRecordingContext *)context overrides:(PrivacyOverrides *)overrides{
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
    FTViewAttributes *attribute = [[FTViewAttributes alloc]initWithView:view frameInRootView:frame clip:newContext.clip overrides:overrides];
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
                PrivacyOverrides *privacy = [PrivacyOverrides mergeChild:subView.sessionReplayPrivacyOverrides parent:view.sessionReplayPrivacyOverrides];
                [self recordRecursively:nodes resources:resource view:subView context:newContext overrides:privacy];
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
