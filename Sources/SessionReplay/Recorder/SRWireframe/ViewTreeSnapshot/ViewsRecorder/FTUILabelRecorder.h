//
//  FTUILabelRecorder.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/24.
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
@protocol FTSRTextObfuscatingProtocol;

NS_ASSUME_NONNULL_BEGIN
@interface FTUILabelBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;

@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) BOOL fontScalingEnabled;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, strong, nullable) FTSRColorSnapshot *textColor;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, assign) NSLineBreakMode lineBreakMode;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end
typedef FTUILabelBuilder* _Nullable (^FTBuilderOverride)(FTUILabelBuilder *builder);

@interface FTUILabelRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic,copy) FTTextObfuscator textObfuscator;
@property (nonatomic,copy) FTBuilderOverride builderOverride;
-(instancetype)initWithIdentifier:(NSString *)identifier builderOverride:(nullable FTBuilderOverride)builderOverride textObfuscator:(nullable FTTextObfuscator)textObfuscator;
@end

NS_ASSUME_NONNULL_END

#endif
