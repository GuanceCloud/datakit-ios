//
//  FTThreadDispatchManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//
#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thread dispatch manager class
@interface FTThreadDispatchManager : NSObject
/// Main thread synchronous execution
/// - Parameter block: Code block
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block;
/// Main thread asynchronous execution
/// - Parameter block: Code block
+ (void)performBlockDispatchMainAsync:(DISPATCH_NOESCAPE dispatch_block_t)block;
@end

NS_ASSUME_NONNULL_END
#endif
