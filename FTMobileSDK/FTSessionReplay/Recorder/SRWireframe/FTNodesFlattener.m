//
//  FTNodesFlattener.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/31.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTNodesFlattener.h"
#import "FTViewAttributes.h"
@implementation FTNodesFlattener
- (NSArray<id<FTSRNodeWireframesBuilder>>*)flattenNodes:(FTViewTreeSnapshot *)snapShot{
    NSMutableArray<id<FTSRNodeWireframesBuilder>> *nodes = (NSMutableArray<id<FTSRNodeWireframesBuilder>>*) [NSMutableArray new];
    for (id<FTSRNodeWireframesBuilder>node in snapShot.nodes) {
        [nodes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<FTSRNodeWireframesBuilder> preNode, NSUInteger idx, BOOL * _Nonnull stop) {
            if (CGRectContainsRect(node.wireframeRect, preNode.wireframeRect) && node.attributes.hasAnyAppearance && !node.attributes.isTranslucent){
                [nodes removeObjectAtIndex:idx];
            }
        }];
        if (CGRectIntersectsRect(CGRectMake(0, 0,snapShot.viewportSize.width, snapShot.viewportSize.height), node.wireframeRect)){
            [nodes addObject:node];
        }
    }
    return nodes;
}
@end
