//
//  FTDisplayRate.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/30.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import "FTSDKCompat.h"
#if FT_HAS_UIKIT
#import <UIKit/UIKit.h>
#import "FTDisplayRateMonitor.h"
#import "FTAppLifeCycle.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
#import "FTLog+Private.h"
#import "FTThreadDispatchManager.h"
@interface FTDisplayRateMonitor()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastFrameTimestamp;
@property (nonatomic, strong) NSPointerArray *dataPublisher;
@property (nonatomic, strong) NSDate *firstFrameDate;
@property (atomic, assign) int startCount;
@end
@implementation FTDisplayRateMonitor
-(instancetype)init{
    self = [super init];
    if (self) {
        _dataPublisher = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
        _startCount = 0;
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
- (void)start{
    self.startCount += 1;
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
            [publisher concurrentWrite:^(FTMonitorValue *value) {
                [value addSample:currentFPS];
            }];
        }
    }else{
        // monitor fist frame
        NSDate *date = [NSDate date];
        self.firstFrameDate = date;
        if (self.callBack) {
            self.callBack(date);
        }
        self.callBack = nil;
    }
    self.lastFrameTimestamp = link.timestamp;
}
-(NSDate *)firstFrameDate{
    return _firstFrameDate;
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
    self.startCount -= 1;
    if (self.startCount == 0) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        self.lastFrameTimestamp = -1;
    }
}
- (void)applicationDidBecomeActive{
    [self start];
}

- (void)applicationWillResignActive{
    [self stop];
}
-(void)dealloc{
    [self stop];
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}
@end
#endif
