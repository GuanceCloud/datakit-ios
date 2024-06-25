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
#import "FTTouchCircle.h"
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
@property (nonatomic, strong) FTViewTreeSnapshotBuilder *viewSnapShot;
@property (nonatomic, strong) FTSnapshotProcessor *snapshotProcessor;
@property (nonatomic, strong) FTResourceProcessor *resourceProcessor;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@end
@implementation FTRecorder
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer writer:(id<FTWriter>)writer{
    self = [super init];
    if(self){
        _windowObserver = observer;
        _viewSnapShot = [[FTViewTreeSnapshotBuilder alloc]init];
        _serialQueue = dispatch_queue_create("com.guance.SRWireframe", DISPATCH_QUEUE_SERIAL);
        _snapshotProcessor = [[FTSnapshotProcessor alloc]init];
        _snapshotProcessor.queue = _serialQueue;
        _snapshotProcessor.writer = writer;
        _resourceProcessor = [[FTResourceProcessor alloc]init];
        _resourceProcessor.queue = _serialQueue;
        FTResourceWriter *resourceWriter = [[FTResourceWriter alloc]init];
        resourceWriter.writer = writer;
        _resourceProcessor.resourceWriter = resourceWriter;
    }
    return self;
}
-(void)taskSnapShot:(FTSRContext *)context touches:(NSMutableArray <FTTouchCircle *> *)touches{
    
    UIView *rootView = self.windowObserver.keyWindow;
    if(rootView == nil){
        return;
    }
    // 1.采集 view snap shot
    FTViewTreeSnapshot *viewTreeSnapshot = [self.viewSnapShot takeSnapshot:rootView context:context];
    
    [self.snapshotProcessor process:viewTreeSnapshot touches:touches];
    [self.resourceProcessor process:viewTreeSnapshot.resources context:context];
}
@end
 
