//
//  FTRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/1.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTRecorder.h"
#import "FTWindowObserver.h"
#import "FTViewAttributes.h"
#import "FTTouchSnapshot.h"
#import "FTViewAttributes.h"
#import "FTSRWireframe.h"
#import "FTSRWireframesBuilder.h"
#import "NSDate+FTUtil.h"
#import "FTSRRecord.h"
#import "FTNodesFlattener.h"
#import "FTSnapshotProcessor.h"
#import "FTResourceProcessor.h"
#import "FTViewTreeSnapshotBuilder.h"
#import "FTResourceWriter.h"
@interface FTRecorder()
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, strong) FTViewTreeSnapshotBuilder *viewSnapShotBuilder;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@end
@implementation FTRecorder
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer
                    snapshotProcessor:(FTSnapshotProcessor *)snapshotProcessor
                    resourceProcessor:(FTResourceProcessor *)resourceProcessor
              additionalNodeRecorders:(NSArray<id <FTSRWireframesRecorder>>*)additionalNodeRecorders;{
    self = [super init];
    if(self){
        _windowObserver = observer;
        _viewSnapShotBuilder = [[FTViewTreeSnapshotBuilder alloc]initWithAdditionalNodeRecorders:additionalNodeRecorders];
        _snapshotProcessor = snapshotProcessor;
        _resourceProcessor = resourceProcessor;
    }
    return self;
}
-(void)taskSnapShot:(FTSRContext *)context touchSnapshot:(FTTouchSnapshot *)touchSnapshot{
    
    UIView *rootView = self.windowObserver.keyWindow;
    if(rootView == nil){
        return;
    }
    // 1.采集 view snap shot
    FTViewTreeSnapshot *viewTreeSnapshot = [self.viewSnapShotBuilder takeSnapshot:rootView context:context];
    
    [self.snapshotProcessor process:viewTreeSnapshot touchSnapshot:touchSnapshot];
    [self.resourceProcessor process:viewTreeSnapshot.resources context:context];
}
@end
 
