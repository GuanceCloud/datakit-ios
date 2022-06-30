//
//  FTDisplayRate.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/6/30.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "FTDisplayRate.h"
#import "FTAppLifeCycle.h"
@interface FTDisplayRate()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastFrameTimestamp;
@end
@implementation FTDisplayRate
-(instancetype)init{
    self = [super init];
    if (self) {
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
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
