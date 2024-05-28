//
//  FTLogDataCache.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTLogDataCache : NSObject
@property (atomic, assign) NSInteger logCount;
@property (atomic, assign) int logCacheLimitCount;
/// logging 类型数据超过最大值后是否废弃最新数据
@property (atomic, assign) BOOL discardNew;
- (instancetype)initWithLogCacheLimitCount:(int)count logDiscardNew:(BOOL)discardNew;

- (void)addLogData:(id)data;
/// 判断日志存储是否到达容量一半
- (BOOL)reachHalfLimit;
- (void)insertCacheToDB;
@end

NS_ASSUME_NONNULL_END
