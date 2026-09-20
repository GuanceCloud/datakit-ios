//
//  FTSerialTimer.h
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

#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTSerialTimer : NSObject
- (instancetype)initWithEventHandler:(dispatch_block_t)eventHandler;
- (instancetype)initWithQueue:(dispatch_queue_t)queue eventHandler:(dispatch_block_t)eventHandler;
- (void)scheduleAfter:(NSTimeInterval)delay leeway:(NSTimeInterval)leeway;
- (void)cancel;
- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
#endif
