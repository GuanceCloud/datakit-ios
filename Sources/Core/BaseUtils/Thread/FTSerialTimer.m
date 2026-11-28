//
//  FTSerialTimer.m
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTSerialTimer.h"

static const char *FTSerialTimerDefaultQueueLabel = "com.ft.serial.timer";

@implementation FTSerialTimer{
    dispatch_queue_t _queue;
    dispatch_source_t _source;
    BOOL _invalidated;
}
- (instancetype)initWithEventHandler:(dispatch_block_t)eventHandler{
    dispatch_queue_t queue = dispatch_queue_create(FTSerialTimerDefaultQueueLabel, DISPATCH_QUEUE_SERIAL);
    return [self initWithQueue:queue eventHandler:eventHandler];
}
- (instancetype)initWithQueue:(dispatch_queue_t)queue eventHandler:(dispatch_block_t)eventHandler{
    self = [super init];
    if (self) {
        _queue = queue;
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
