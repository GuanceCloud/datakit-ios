//
//  FTMemoryMonitor.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/1.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 内存监控器
@interface FTMemoryMonitor : NSObject
/// 内存使用量
- (double)memoryUsage;
@end

NS_ASSUME_NONNULL_END
