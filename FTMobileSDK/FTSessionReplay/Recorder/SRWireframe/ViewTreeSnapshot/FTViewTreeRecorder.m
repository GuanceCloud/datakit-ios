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
    FTViewAttributes *attribute = [[FTViewAttributes alloc]initWithFrameInRootView:[view convertRect:view.bounds toCoordinateSpace:context.coordinateSpace] view:view];
    
    if (attribute.isVisible){
        return;
    }

    {
        NSArray<id <FTSRWireframesBuilder>> *builders;
        for (id<FTSRWireframesRecorder> recorder in self.nodeRecorders) {
            id<FTSRNodeSemantics> newBuilders = [recorder recorder:view attributes:attribute context:context];
            if(newBuilders && newBuilders.nodes.count>0){
                builders = newBuilders.nodes;
            }
        }
        
        for (UIView *subView in view.subviews) {
            [self recordRecursively:nodes resources:resource view:subView context:context];
        }
    }
}
@end
