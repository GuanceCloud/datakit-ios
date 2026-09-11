//
//  FTRecorder.m
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

#import "FTRecorder.h"
#import "FTWindowObserver.h"
#import "FTViewAttributes.h"
#import "FTTouchSnapshot.h"
#import "FTViewAttributes.h"
#import "FTSRWireframe.h"
#import "FTSRNodeWireframesBuilder.h"
#import "FTSessionReplayCoreImports.h"
#import "FTSRRecord.h"
#import "FTNodesFlattener.h"
#import "FTSnapshotProcessor.h"
#import "FTViewTreeSnapshotBuilder.h"
#import "FTResourcesWriter.h"
@interface FTRecorder()
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong) FTViewTreeSnapshotBuilder *viewSnapShotBuilder;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@end
@implementation FTRecorder
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer
                    snapshotProcessor:(FTSnapshotProcessor *)snapshotProcessor
              additionalNodeRecorders:(NSArray<id <FTSRWireframesRecorder>>*)additionalNodeRecorders
                        enableSwiftUI:(BOOL)enableSwiftUI
                        enableHeatmap:(BOOL)enableHeatmap{
    self = [super init];
    if(self){
        _windowObserver = observer;
        _viewSnapShotBuilder = [[FTViewTreeSnapshotBuilder alloc]initWithAdditionalNodeRecorders:additionalNodeRecorders enableSwiftUI:enableSwiftUI];
        _viewSnapShotBuilder.enableHeatmap = enableHeatmap;
        _snapshotProcessor = snapshotProcessor;
    }
    return self;
}
-(void)taskSnapShot:(FTSRContext *)context touchSnapshot:(FTTouchSnapshot *)touchSnapshot{

    NSAssert(NSThread.isMainThread, @"Session Replay view capture must run on the main thread.");
    NSArray<FTSRPlatformView *> *rootViews = self.windowObserver.rootViews;
    FTSRPlatformView *referenceView = self.windowObserver.referenceView;
    if(rootViews == nil || rootViews.count == 0 || referenceView == nil){
        return;
    }
    // 1.Collect view snap shot
    FTViewTreeSnapshot *viewTreeSnapshot = [self.viewSnapShotBuilder takeSnapshot:rootViews referenceView:referenceView context:context];
    [self.snapshotProcessor process:viewTreeSnapshot touchSnapshot:touchSnapshot];
}
-(void)forceFullSnapshot{
    [self.snapshotProcessor forceFullSnapshot];
}
@end
 

#endif
