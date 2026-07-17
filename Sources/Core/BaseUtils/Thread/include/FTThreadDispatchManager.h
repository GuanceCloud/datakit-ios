//
//  FTThreadDispatchManager.h
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

+ (BOOL)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block timeout:(NSTimeInterval)timeout;
@end

NS_ASSUME_NONNULL_END
#endif
