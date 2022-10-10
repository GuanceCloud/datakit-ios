//
//  FTDisplayRate.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/30.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif
#import "FTDisplayRateMonitor.h"
#import "FTAppLifeCycle.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
#import "FTLog.h"
#import "FTThreadDispatchManager.h"
@interface FTDisplayRateMonitor()<FTAppLifeCycleDelegate>
#if !TARGET_OS_OSX
@property (nonatomic, strong) CADisplayLink *displayLink;
#endif
@property (nonatomic, assign) CFTimeInterval lastFrameTimestamp;
@property (nonatomic, strong) NSPointerArray *dataPublisher;

@end
@implementation FTDisplayRateMonitor
#if !TARGET_OS_OSX
-(instancetype)init{
    self = [super init];
    if (self) {
        _dataPublisher = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];

        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
        [self start];
    }
    return self;
}
- (void)start{
    if (self.displayLink) {
        return;
    }
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLink:)];
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)displayLink:(CADisplayLink *)link{
    if (self.lastFrameTimestamp > 0) {
        double frameDuration = link.timestamp - self.lastFrameTimestamp;
        double currentFPS = 1.0 / frameDuration;
        for (id publisher in self.dataPublisher) {
            [publisher concurrentWrite:^(id  _Nonnull value) {
                if([value isKindOfClass: FTMonitorValue.class]){
                    FTMonitorValue *newValue = value;
                    [newValue addSample:currentFPS];
                }
            }];
        }
    }
    self.lastFrameTimestamp = link.timestamp;
}
- (void)addMonitorItem:(FTReadWriteHelper<FTMonitorValue *> *)item{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        if (![self.dataPublisher.allObjects containsObject:item]) {
            [self.dataPublisher addPointer:(__bridge void *)item];
        }
    }];
}
- (void)removeMonitorItem:(FTReadWriteHelper<FTMonitorValue *> *)item{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        for (NSUInteger i=0; i<self.dataPublisher.count; i++) {
            if ([self.dataPublisher pointerAtIndex:i] == (__bridge void *)item) {
                [self.dataPublisher removePointerAtIndex:i];
                break;
            }
        }
    }];
}
- (void)stop{
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.lastFrameTimestamp = -1;
}
- (void)applicationDidBecomeActive{
    [self start];
}

- (void)applicationWillResignActive{
    [self stop];
}
#endif
@end
