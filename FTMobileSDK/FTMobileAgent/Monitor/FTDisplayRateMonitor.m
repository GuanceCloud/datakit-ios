//
//  FTDisplayRate.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/30.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "FTDisplayRateMonitor.h"
#import "FTAppLifeCycle.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
@interface FTDisplayRateMonitor()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastFrameTimestamp;
@property (nonatomic, strong) NSPointerArray *dataPublisher;
@property (nonatomic, strong) NSLock *dataLock;

@end
@implementation FTDisplayRateMonitor
-(instancetype)init{
    self = [super init];
    if (self) {
        _dataPublisher = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
        _dataLock = [[NSLock alloc] init];

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
        [self.dataLock lock];
        for (id publisher in self.dataPublisher) {
            [publisher concurrentWrite:^(id  _Nonnull value) {
                if([value isKindOfClass: FTMonitorValue.class]){
                    FTMonitorValue *newValue = value;
                    [newValue addSample:currentFPS];
                }
            }];
        }
        [self.dataLock unlock];
    }
    
    self.lastFrameTimestamp = link.timestamp;
}
- (void)addMonitorItem:(FTReadWriteHelper<FTMonitorValue *> *)item{
    [self.dataLock lock];
    if (![self.dataPublisher.allObjects containsObject:item]) {
        [self.dataPublisher addPointer:(__bridge void *)item];
    }
    [self.dataLock unlock];
}
- (void)removeMonitorItem:(FTReadWriteHelper<FTMonitorValue *> *)item{
    [self.dataLock lock];
    for (NSUInteger i=0; i<self.dataPublisher.count; i++) {
        if ([self.dataPublisher pointerAtIndex:i] == (__bridge void *)item) {
            [self.dataPublisher removePointerAtIndex:i];
            break;
        }
    }
    [self.dataLock unlock];
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
@end
