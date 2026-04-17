//
//  FTCALayerChangeAggregator.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/3.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTCALayerChangeAggregator.h"
#import "FTCALayerSwizzler.h"
@interface FTCALayerChangeAggregator()

@property (nonatomic, assign, readwrite) BOOL running;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, FTCALayerChange *> *pendingChanges;
@property (nonatomic, assign) NSTimeInterval lastDeliveryTime;
@property (nonatomic, strong) id<FTScheduledTimer> scheduledDelivery;
@property (nonatomic, copy) void (^handler)(FTCALayerChangeSnapshot *snapshot);

#pragma mark - private
- (void)recordLayer:(CALayer *)layer aspect:(FTCALayerChangeAspect)aspect;
- (void)scheduleDeliveryIfNeeded;
- (void)scheduleDeliveryAfterDelay:(NSTimeInterval)delay;
- (void)deliverPendingChangesWithNow:(NSTimeInterval)now;
@end
@implementation FTCALayerChangeAggregator
- (instancetype)initWithMinimumDeliveryInterval:(NSTimeInterval)minimumDeliveryInterval
                                 timerScheduler:(id<FTTimerScheduler>)timerScheduler
                                        handler:(void (^)(FTCALayerChangeSnapshot *snapshot))handler {
    if (self = [super init]) {
        _minimumDeliveryInterval = minimumDeliveryInterval;
        _timerScheduler = timerScheduler;
        _handler = [handler copy];
        _pendingChanges = [NSMutableDictionary dictionary];
        _running = NO;
    }
    return self;
}

- (void)dealloc {
    [self stop];
    self.handler = nil;
}

#pragma mark - Public
- (void)start {
    if (self.isRunning) {
        return;
    }
    
    self.running = YES;
    self.lastDeliveryTime = self.timerScheduler.now;
}

- (void)stop {
    if (!self.isRunning) {
        return;
    }
    
    self.running = NO;
    [self.pendingChanges removeAllObjects];
    [self.scheduledDelivery cancel];
    self.scheduledDelivery = nil;
}

#pragma mark ======== FTCALayerObserver =========
-(void)layerDidDisplay:(CALayer *)layer{
    [self recordLayer:layer aspect:FTCALayerChangeAspectDisplay];
}
-(void)layerDidDraw:(CALayer *)layer inContext:(CGContextRef)context{
    [self recordLayer:layer aspect:FTCALayerChangeAspectDraw];
}
- (void)layerDidLayoutSublayers:(nonnull CALayer *)layer { 
    [self recordLayer:layer aspect:FTCALayerChangeAspectLayout];
}
#pragma mark - private
- (void)recordLayer:(CALayer *)layer aspect:(FTCALayerChangeAspect)aspect {
    if (![NSThread isMainThread] || !self.isRunning) {
        return;
    }
    
    NSNumber *layerKey = @((uintptr_t)layer);
    FTCALayerChange *layerChange = self.pendingChanges[layerKey];
    
    if (layerChange) {
        
        layerChange.aspects |= aspect;
        self.pendingChanges[layerKey] = layerChange;
    } else {
        layerChange = [[FTCALayerChange alloc] initWithLayer:layer aspects:aspect];
        self.pendingChanges[layerKey] = layerChange;
    }
    
    [self scheduleDeliveryIfNeeded];
}

- (void)scheduleDeliveryIfNeeded {
    NSTimeInterval now = self.timerScheduler.now;
    
    if (self.lastDeliveryTime == 0) {
        self.lastDeliveryTime = now;
        if (self.scheduledDelivery == nil) {
            [self scheduleDeliveryAfterDelay:self.minimumDeliveryInterval];
        }
        return;
    }
    
    if (self.scheduledDelivery) {
        return;
    }

    NSTimeInterval elapsed = now - self.lastDeliveryTime;
    NSTimeInterval delay =  MAX(0, self.minimumDeliveryInterval - elapsed);
    [self scheduleDeliveryAfterDelay:delay];
}

- (void)scheduleDeliveryAfterDelay:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    self.scheduledDelivery = [self.timerScheduler scheduleAfterInterval:delay action:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        strongSelf.scheduledDelivery = nil;
        [strongSelf deliverPendingChangesWithNow:strongSelf.timerScheduler.now];
    }];
}

- (void)deliverPendingChangesWithNow:(NSTimeInterval)now {
    FTCALayerChangeSnapshot *snapshot = [[FTCALayerChangeSnapshot alloc] initWithChanges:self.pendingChanges];
    snapshot = [snapshot removingDeallocatedLayers];
    
    [self.pendingChanges removeAllObjects];
    self.lastDeliveryTime = now;
    
    if (snapshot.changes.count > 0 && self.handler) {
        self.handler(snapshot);
    }
}
@end
