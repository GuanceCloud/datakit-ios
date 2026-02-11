//
//  FTThreadDispatchManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//
#ifdef __OBJC__
#import "FTThreadDispatchManager.h"
@implementation FTThreadDispatchManager
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block{
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
+ (void)performBlockDispatchMainAsync:(DISPATCH_NOESCAPE dispatch_block_t)block{
    dispatch_async(dispatch_get_main_queue(), block);
}
+ (BOOL)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block timeout:(NSTimeInterval)timeout{
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        dispatch_async(dispatch_get_main_queue(), ^{
            block();
            dispatch_semaphore_signal(semaphore);
        });

        dispatch_time_t timeout_t
            = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC));
        return dispatch_semaphore_wait(semaphore, timeout_t) == 0;
    }
    return YES;
}

@end
#endif
