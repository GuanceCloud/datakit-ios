//
//  FTViewTreeSnapshotBuilder.h
//  SessionReplay
//
//  Created by hulilei on 2023/7/17.
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
#if TARGET_OS_IOS || TARGET_OS_OSX

#import <Foundation/Foundation.h>
#import "FTSessionReplayPlatform.h"
#import <WebKit/WKWebView.h>
NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTSRContext;
@protocol FTSRWireframesRecorder;
@interface FTViewTreeSnapshotBuilder : NSObject
@property (nonatomic, strong) NSArray<id <FTSRWireframesRecorder>> *recorders;
@property (nonatomic, strong) NSHashTable<WKWebView*> *webViewCache;
@property (nonatomic, assign) BOOL enableHeatmap;
- (FTViewTreeSnapshot *)takeSnapshot:(NSArray <FTSRPlatformView *> *)rootViews referenceView:(FTSRPlatformView *)referenceView context:(FTSRContext *)context;
-(instancetype)initWithAdditionalNodeRecorders:(nullable NSArray <id <FTSRWireframesRecorder>>*)additionalNodeRecorders;
-(instancetype)initWithAdditionalNodeRecorders:(nullable NSArray <id <FTSRWireframesRecorder>>*)additionalNodeRecorders enableSwiftUI:(BOOL)enableSwiftUI;
@end

NS_ASSUME_NONNULL_END

#endif
