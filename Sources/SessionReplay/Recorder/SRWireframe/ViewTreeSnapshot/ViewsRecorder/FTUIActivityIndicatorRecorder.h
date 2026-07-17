//
//  FTUIActivityIndicatorRecorder.h
//  SessionReplay
//
//  Created by hulilei on 2024/7/12.
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
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes,FTViewTreeRecorder, FTSRColorSnapshot;
NS_ASSUME_NONNULL_BEGIN

@interface FTUIActivityIndicatorBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong, nullable) FTSRColorSnapshot * backgroundColor;
@end

@interface FTUIActivityIndicatorRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end
NS_ASSUME_NONNULL_END

#endif
