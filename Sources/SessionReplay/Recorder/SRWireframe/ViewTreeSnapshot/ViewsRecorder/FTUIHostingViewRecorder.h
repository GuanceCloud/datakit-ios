//
//  FTUIHostingViewRecorder.h
//  SessionReplay
//
//  Created by hulilei on 2026/4/29.
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

@interface FTUIHostingViewBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong, nullable) id recordingBuilder;
@property (nonatomic, strong, nullable) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end

@interface FTUIHostingViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) SemanticsOverride semanticsOverride;
@property (nonatomic, copy) FTTextObfuscator textObfuscator;

- (instancetype)initWithIdentifier:(NSString *)identifier;
- (instancetype)initWithIdentifier:(NSString *)identifier
                 semanticsOverride:(nullable SemanticsOverride)semanticsOverride
                     textObfuscator:(nullable FTTextObfuscator)textObfuscator;
+ (BOOL)isSwiftUIGraphicsView:(UIView *)view;
@end

NS_ASSUME_NONNULL_END

#endif
