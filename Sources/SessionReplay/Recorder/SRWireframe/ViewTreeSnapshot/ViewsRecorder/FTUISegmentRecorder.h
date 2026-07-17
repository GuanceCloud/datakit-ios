//
//  FTUISegmentRecorder.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/29.
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

@class FTViewAttributes, FTSRColorSnapshot;
NS_ASSUME_NONNULL_BEGIN
@interface FTUISegmentBuilder:NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong, nullable) NSNumber *selectedSegmentIndex;
@property (nonatomic, strong) NSArray *segmentTitles;
@property (nonatomic, strong) NSArray *segmentWireframeIDs;
@property (nonatomic, strong, nullable) FTSRColorSnapshot *selectedSegmentTintColor;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end
@interface FTUISegmentRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic,copy) FTTextObfuscator textObfuscator;
-(instancetype)initWithIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END

#endif
