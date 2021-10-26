//
//  FTThreadDispatchManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTThreadDispatchManager : NSObject
+ (void)dispatchInRUMThread:(void (^_Nullable)(void))block;
+ (void)dispatchSyncInRUMThread:(void (^_Nullable)(void))block;
/**
 * 主线程同步执行
 */
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block;
/**
 * 主线程异步执行
 */
+ (void)performBlockDispatchMainAsync:(DISPATCH_NOESCAPE dispatch_block_t)block;
@end

NS_ASSUME_NONNULL_END
