//
//  FTNodesFlattener.h
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

#import <Foundation/Foundation.h>
#import "FTSRNodeWireframesBuilder.h"
NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot;
@interface FTNodesFlattener : NSObject
- (NSArray<id <FTSRNodeWireframesBuilder>>*)flattenNodes:(FTViewTreeSnapshot *)snapShot;
@end

NS_ASSUME_NONNULL_END

#endif
