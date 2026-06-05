//
//  FTSerialTimer.m
//  FTMobileSDK
//
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTSerialTimer.h"

@implementation FTSerialTimer{
    dispatch_source_t _source;
    BOOL _invalidated;
}
- (instancetype)initWithQueue:(dispatch_queue_t)queue eventHandler:(dispatch_block_t)eventHandler{
    self = [super init];
    if (self) {
        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_event_handler(_source, eventHandler);
        dispatch_resume(_source);
    }
    return self;
}
- (void)scheduleAfter:(NSTimeInterval)delay leeway:(NSTimeInterval)leeway{
    @synchronized (self) {
        if (_invalidated || !_source) {
            return;
        }
        dispatch_source_set_timer(_source,
                                  dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                                  DISPATCH_TIME_FOREVER,
                                  (uint64_t)(leeway * NSEC_PER_SEC));
    }
}
- (void)cancel{
    @synchronized (self) {
        if (_invalidated || !_source) {
            return;
        }
        dispatch_source_set_timer(_source, DISPATCH_TIME_FOREVER, DISPATCH_TIME_FOREVER, 0);
    }
}
- (void)invalidate{
    dispatch_source_t source = nil;
    @synchronized (self) {
        if (_invalidated) {
            return;
        }
        _invalidated = YES;
        source = _source;
        _source = nil;
    }
    if (source) {
        dispatch_source_cancel(source);
    }
}
- (void)dealloc{
    [self invalidate];
}
@end
