//
//  FTSwiftUIReflectionBridge.h
//  SessionReplay
//
//  Created by hulilei on 2026/5/6.
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

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRecordingAttributes : NSObject
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect clip;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, nullable) CGColorRef backgroundColor;
@property (nonatomic, nullable) CGColorRef borderColor;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) NSInteger textPrivacy;
@property (nonatomic, assign) NSInteger imagePrivacy;
@property (nonatomic, assign) int64_t wireframeID;
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRecordingResult : NSObject
@property (nonatomic, strong, readonly) NSArray *wireframes;
@property (nonatomic, strong, readonly) NSArray *resources;
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRenderer : NSObject
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIRecordingBuilder : NSObject
- (nullable FTSwiftUIRecordingResult *)build;
@end

API_AVAILABLE(ios(13.0))
@interface FTSwiftUIReflectionBridge : NSObject
- (FTSwiftUIRecordingAttributes *)makeRecordingAttributes;
- (nullable FTSwiftUIRenderer *)rendererForHostingView:(UIView *)view;
- (nullable FTSwiftUIRecordingBuilder *)recordingBuilderForRenderer:(FTSwiftUIRenderer *)renderer attributes:(FTSwiftUIRecordingAttributes *)attributes;
@end

NS_ASSUME_NONNULL_END

#endif
