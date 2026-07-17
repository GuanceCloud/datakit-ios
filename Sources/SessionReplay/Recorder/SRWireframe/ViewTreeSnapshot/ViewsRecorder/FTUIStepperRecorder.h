//
//  FTUIStepperRecorder.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/28.
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

@class FTViewAttributes;
NS_ASSUME_NONNULL_BEGIN
@interface FTUIStepperBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, assign) int dividerWireframeID;
@property (nonatomic, assign) int minusWireframeID;
@property (nonatomic, assign) int plusHorizontalWireframeID;
@property (nonatomic, assign) int plusVerticalWireframeID;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) CGFloat cornerRadius;
/// Whether LeftSegment click is allowed
///  When current value is at minimum, `—` is not clickable, displays gray
///  (14,2)
@property (nonatomic, assign) BOOL isMinusEnabled;
/// Whether RightSegment click is allowed
///  When current value is at maximum, `+` is not clickable, displays gray
///  (14,12)
@property (nonatomic, assign) BOOL isPlusEnabled;
@end
@interface FTUIStepperRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;

@end

NS_ASSUME_NONNULL_END

#endif
