//
//  FTThreadDispatchManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTThreadDispatchManager.h"
#import "FTConstants.h"
#import "FTRumThread.h"
@implementation FTThreadDispatchManager
+ (void)dispatchInRUMThread:(void (^_Nullable)(void))block {
    if ([[NSThread currentThread] isEqual:[FTRumThread sharedThread]]) {
        block();
    } else {
        [FTThreadDispatchManager performSelector:@selector(dispatchBlock:)
                                       onThread:[FTRumThread sharedThread]
                                     withObject:block
                                  waitUntilDone:NO];
    }
}
+ (void)dispatchSyncInRUMThread:(void (^_Nullable)(void))block{
    
    [FTThreadDispatchManager performSelector:@selector(dispatchBlock:)
                                    onThread:[FTRumThread sharedThread]
                                  withObject:block
                               waitUntilDone:YES];
}
+ (void)dispatchBlock:(void (^_Nullable)(void))block {
    if (block) {
        block();
    }
}
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block{
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
+ (void)performBlockDispatchMainAsync:(DISPATCH_NOESCAPE dispatch_block_t)block{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}
@end
