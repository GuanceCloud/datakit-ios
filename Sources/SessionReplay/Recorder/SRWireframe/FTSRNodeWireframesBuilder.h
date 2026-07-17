//
//  FTSRNodeWireframesBuilder.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/8.
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
@class FTSRWireframe,FTViewAttributes,FTViewTreeRecordingContext,FTSRNodeSemantics,FTSessionReplayWireframesBuilder,FTHeatmapIdentifier;
@protocol FTSRTextObfuscatingProtocol;

typedef FTSRNodeSemantics* _Nullable(^SemanticsOverride)(UIView *  view, FTViewAttributes* attributes);
typedef id<FTSRTextObfuscatingProtocol> _Nullable(^FTTextObfuscator)(FTViewTreeRecordingContext *context,FTViewAttributes *attributes);

@protocol FTSRNodeWireframesBuilder <NSObject>
- (FTViewAttributes*)attributes;
- (CGRect)wireframeRect;
- (NSArray<FTSRWireframe *>*)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder;;
@optional
@property (nonatomic, strong, readonly, nullable) FTHeatmapIdentifier *heatmapIdentifier;
@end

@protocol FTSRWireframesRecorder <NSObject>
@property (nonatomic, copy) NSString *identifier;
-(nullable FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context;
@end

@protocol FTSRResource <NSObject>
@property (nonatomic, copy) NSString *mimeType;
- (NSString *)calculateIdentifier;
- (NSData *)calculateData;
@end
NS_ASSUME_NONNULL_END

#endif
