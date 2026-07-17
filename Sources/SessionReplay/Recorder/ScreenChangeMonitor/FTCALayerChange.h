//
//  FTCALayerChange.h
//  SessionReplay
//
//  Created by hulilei on 2026/3/3.
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
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_OPTIONS(NSUInteger, FTCALayerChangeAspect) {
    FTCALayerChangeAspectDisplay = 1 << 0,
    FTCALayerChangeAspectDraw    = 1 << 1,
    FTCALayerChangeAspectLayout  = 1 << 2
};

@interface FTCALayerChange : NSObject
@property (nonatomic, weak, nullable, readonly) CALayer *layer;
@property (nonatomic, assign) FTCALayerChangeAspect aspects;

- (instancetype)initWithLayer:(CALayer *)layer aspects:(FTCALayerChangeAspect)aspects;
@end

NS_ASSUME_NONNULL_END

#endif
