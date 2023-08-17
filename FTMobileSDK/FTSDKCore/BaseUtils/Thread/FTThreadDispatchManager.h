//
//  FTThreadDispatchManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 线程派发管理类
@interface FTThreadDispatchManager : NSObject
/// 主线程同步执行
/// - Parameter block: 代码块
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block;
/// 主线程异步执行
/// - Parameter block: 代码块
+ (void)performBlockDispatchMainAsync:(DISPATCH_NOESCAPE dispatch_block_t)block;
@end

NS_ASSUME_NONNULL_END
