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
@interface FTDisplayRateMonitor()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastFrameTimestamp;
@property(strong, nonatomic, readonly) NSPointerArray *dataPublisher;

@end
@implementation FTDisplayRateMonitor
-(instancetype)init{
    self = [super init];
    if (self) {
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
        
    }
    
    self.lastFrameTimestamp = link.timestamp;
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
