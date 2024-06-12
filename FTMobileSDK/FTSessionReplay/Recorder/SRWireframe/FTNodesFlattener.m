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
- (NSArray<id<FTSRWireframesBuilder>>*)flattenNodes:(FTViewTreeSnapshot *)snapShot{
    NSMutableArray<id<FTSRWireframesBuilder>> *nodes = (NSMutableArray<id<FTSRWireframesBuilder>>*) [NSMutableArray new];
    for (id<FTSRWireframesBuilder>node in snapShot.nodes) {
        [nodes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<FTSRWireframesBuilder> preNode, NSUInteger idx, BOOL * _Nonnull stop) {
            if (CGRectContainsRect(node.wireframeRect, preNode.wireframeRect) && node.attributes.hasAnyAppearance && !node.attributes.isTranslucent){
                [nodes removeObjectAtIndex:idx];
            }
        }];
        [nodes addObject:node];
    }
    return nodes;
}
@end
