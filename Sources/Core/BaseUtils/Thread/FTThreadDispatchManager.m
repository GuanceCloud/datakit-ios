//
//  FTThreadDispatchManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/20.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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
