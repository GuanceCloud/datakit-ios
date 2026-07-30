//
//  FTRecorder.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/1.
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

NS_ASSUME_NONNULL_BEGIN
@class FTWindowObserver,FTSRContext,FTTouchSnapshot,FTSnapshotProcessor;
@protocol FTWriter,FTSRWireframesRecorder;
@interface FTRecorder : NSObject
@property (nonatomic, strong) FTSnapshotProcessor *snapshotProcessor;
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer snapshotProcessor:(FTSnapshotProcessor *)snapshotProcessor 
              additionalNodeRecorders:(NSArray<id <FTSRWireframesRecorder>>*)additionalNodeRecorders
                        enableSwiftUI:(BOOL)enableSwiftUI
                        enableHeatmap:(BOOL)enableHeatmap;
;
-(void)taskSnapShot:(FTSRContext *)context touchSnapshot:(nullable FTTouchSnapshot *)touchSnapshot;
@end

NS_ASSUME_NONNULL_END

#endif
