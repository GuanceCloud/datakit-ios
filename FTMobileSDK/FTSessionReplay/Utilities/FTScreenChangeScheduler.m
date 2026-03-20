//
//  FTScreenChangeScheduler.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/3/2.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTScreenChangeScheduler.h"
#import "FTQueue.h"
#import "FTScreenChangeMonitor.h"
@interface FTScreenChangeScheduler()
@property (nonatomic, strong) id<FTQueue> queue;
@property (nonatomic, assign) NSTimeInterval minimumInterval;
@property (nonatomic, strong) FTScreenChangeMonitor *monitor;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *operations;

@end

@implementation FTScreenChangeScheduler
- (instancetype)initWithMinimumInterval:(NSTimeInterval)minimumInterval
                         timerScheduler:(id<FTTimerScheduler>)timerScheduler {
    if (self = [super init]) {
        _minimumInterval = minimumInterval;
        _timerScheduler = timerScheduler ?: FTDispatchSourceTimerScheduler.dispatchSource;
        _queue = [[FTMainQueue alloc] init];
        _operations = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithMinimumInterval:(NSTimeInterval)minimumInterval{
    return [self initWithMinimumInterval:minimumInterval
                         timerScheduler:FTDispatchSourceTimerScheduler.dispatchSource];
}

#pragma mark - Scheduler
- (void)scheduleWithOperation:(dispatch_block_t)operation {
    if (!operation) {
        return;
    }
    [self.queue run:^{
        [self.operations addObject:[operation copy]];
    }];
}

- (void)start {
    __weak typeof(self) weakSelf = self;
    [self.queue run:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (strongSelf.monitor) {
            return;
        }
        
        FTScreenChangeMonitor *monitor = [[FTScreenChangeMonitor alloc] initWithMinimumDeliveryInterval:strongSelf.minimumInterval timerScheduler:strongSelf.timerScheduler handler:^(FTCALayerChangeSnapshot * _Nonnull snapshot) {
            [strongSelf screenDidChange:snapshot];
        }];
        
        if (monitor) {
            [monitor start];
            strongSelf.monitor = monitor;
        } else {
            //
        }
    }];
}

- (void)stop {
    __weak typeof(self) weakSelf = self;
    
    [self.queue run:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.monitor) {
            return;
        }
        
        [strongSelf.monitor stop];
        strongSelf.monitor = nil;
    }];
}

- (void)screenDidChange:(FTCALayerChangeSnapshot *)snapshot {
    
    [self.operations enumerateObjectsUsingBlock:^(dispatch_block_t  _Nonnull operation, NSUInteger idx, BOOL * _Nonnull stop) {
        operation();
    }];

}


@end
