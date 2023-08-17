//
//  FTThreadDispatchManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

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
@end
