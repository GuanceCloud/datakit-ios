//
//  FTUIImageViewRecorder.h
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
@class FTViewAttributes,FTUIImageResource;

NS_ASSUME_NONNULL_BEGIN
typedef UIColor* _Nullable(^FTTintColorProvider)(UIImageView *imageView);
typedef BOOL (^FTShouldRecordImagePredicate)(UIImageView *imageView);

@interface FTUIImageViewBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, assign) int imageWireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect contentFrame;

@property (nonatomic, strong, nullable) FTUIImageResource *imageResource;
@property (nonatomic, assign) CGRect wireframeRect;
@end
@interface FTUIImageViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) SemanticsOverride semanticsOverride;
@property (nonatomic, copy, nullable) FTShouldRecordImagePredicate shouldRecordImagePredicateOverride;
@property (nonatomic, copy) FTTintColorProvider tintColorProvider;

@property (nonatomic, copy) NSString *identifier;
-(instancetype)initWithIdentifier:(NSString *)identifier
                tintColorProvider:(nullable FTTintColorProvider)tintColorProvider
shouldRecordImagePredicateOverride:(nullable FTShouldRecordImagePredicate)shouldRecordImagePredicateOverride;
@end

NS_ASSUME_NONNULL_END

#endif
