//
//  FTUIImageResource.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/14.
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
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface FTUIImageResource : NSObject<FTSRResource>
-(instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor;
-(instancetype)initWithImage:(UIImage *)image tintColor:(nullable UIColor *)tintColor traitCollection:(nullable UITraitCollection *)traitCollection;
@end

NS_ASSUME_NONNULL_END

#endif
