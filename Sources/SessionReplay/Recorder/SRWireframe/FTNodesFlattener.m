//
//  FTNodesFlattener.m
//  SessionReplay
//
//  Created by hulilei on 2023/8/31.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTNodesFlattener.h"
#import "FTViewAttributes.h"
#import <stdlib.h>
@implementation FTNodesFlattener
- (NSArray<id<FTSRNodeWireframesBuilder>>*)flattenNodes:(FTViewTreeSnapshot *)snapShot{
    NSArray<id<FTSRNodeWireframesBuilder>> *snapshotNodes = snapShot.nodes ?: @[];
    NSUInteger nodeCount = snapshotNodes.count;
    if (nodeCount == 0) {
        return @[];
    }

    CGRect viewportRect = CGRectMake(0, 0, snapShot.viewportSize.width, snapShot.viewportSize.height);
    NSMutableArray<id<FTSRNodeWireframesBuilder>> *flattened = [NSMutableArray arrayWithCapacity:nodeCount];
    CGRect *opaqueFrames = calloc(nodeCount, sizeof(CGRect));
    if (!opaqueFrames) {
        NSMutableArray<id<FTSRNodeWireframesBuilder>> *visibleNodes = [NSMutableArray arrayWithCapacity:nodeCount];
        for (id<FTSRNodeWireframesBuilder> node in snapshotNodes) {
            CGRect nodeFrame = node.wireframeRect;
            if (CGRectIntersectsRect(viewportRect, nodeFrame)) {
                [visibleNodes addObject:node];
            }
        }
        return visibleNodes;
    }

    NSUInteger opaqueFramesCount = 0;
    for (NSUInteger index = nodeCount; index > 0; index--) {
        id<FTSRNodeWireframesBuilder> node = snapshotNodes[index - 1];
        CGRect nodeFrame = node.wireframeRect;
        if (!CGRectIntersectsRect(viewportRect, nodeFrame)) {
            continue;
        }

        BOOL isOccluded = NO;
        for (NSUInteger opaqueFrameIndex = 0; opaqueFrameIndex < opaqueFramesCount; opaqueFrameIndex++) {
            if (CGRectContainsRect(opaqueFrames[opaqueFrameIndex], nodeFrame)) {
                isOccluded = YES;
                break;
            }
        }
        if (isOccluded) {
            continue;
        }

        [flattened addObject:node];
        FTViewAttributes *attributes = node.attributes;
        if (attributes.hasAnyAppearance && !attributes.isTranslucent) {
            opaqueFrames[opaqueFramesCount] = nodeFrame;
            opaqueFramesCount++;
        }
    }

    free(opaqueFrames);
    return [[flattened reverseObjectEnumerator] allObjects];
}
@end

#endif
