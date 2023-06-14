//
//  FTUncaughtExceptionHandler.h
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTErrorDataProtocol.h"
NS_ASSUME_NONNULL_BEGIN

/// 崩溃采集工具
@interface FTUncaughtExceptionHandler : NSObject

/// 单例
+ (instancetype)sharedHandler;
/// 添加处理 error data 的代理对象
/// - Parameter delegate: 代理对象
- (void)addErrorDataDelegate:(id <FTErrorDataDelegate>)delegate;
/// 移除处理 error data 的代理对象
/// - Parameter delegate: 代理对象
- (void)removeErrorDataDelegate:(id <FTErrorDataDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
