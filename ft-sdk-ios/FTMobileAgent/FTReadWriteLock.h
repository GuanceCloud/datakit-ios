//
//  FTReadWriteLock.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/7/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTReadWriteLock : NSObject
- (instancetype)initWithQueueLabel:(NSString *)queueLabel NS_DESIGNATED_INITIALIZER;

/// 禁用 init 初始化
- (instancetype)init NS_UNAVAILABLE;

/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
- (id)readWithBlock:(id(^)(void))block;
- (void)writeWithBlock:(void (^)(void))block;
@end

NS_ASSUME_NONNULL_END
