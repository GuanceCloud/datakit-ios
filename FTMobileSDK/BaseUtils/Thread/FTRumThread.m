//
//  FTRumThread.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTRumThread.h"
@interface FTRumThread () {
    dispatch_group_t _waitGroup;
}
@property (nonatomic, strong, readwrite) NSRunLoop *runLoop;

@end
@implementation FTRumThread

+ (instancetype)sharedThread {
    static FTRumThread *thread;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[FTRumThread alloc] init];
        thread.name = @"com.dataflux.rum.thread";
        [thread start];
    });
    return thread;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _waitGroup = dispatch_group_create();
        dispatch_group_enter(_waitGroup);
    }
    return self;
}

- (void)main {
    @autoreleasepool {
        _runLoop = [NSRunLoop currentRunLoop];
        dispatch_group_leave(_waitGroup);

        // Add an empty run loop source to prevent runloop from spinning.
        CFRunLoopSourceContext sourceCtx = {.version = 0,
                                            .info = NULL,
                                            .retain = NULL,
                                            .release = NULL,
                                            .copyDescription = NULL,
                                            .equal = NULL,
                                            .hash = NULL,
                                            .schedule = NULL,
                                            .cancel = NULL,
                                            .perform = NULL};
        CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &sourceCtx);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);

        while ([_runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
        }
        assert(NO);
    }
}

- (NSRunLoop *)runLoop;
{
    dispatch_group_wait(_waitGroup, DISPATCH_TIME_FOREVER);
    return _runLoop;
}
@end
