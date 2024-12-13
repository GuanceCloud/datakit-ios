//
//  FTLogDataCache.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTDBDataCachePolicy : NSObject
@property (atomic, assign) NSInteger logCount;
@property (atomic, assign) NSInteger rumCount;
@property (atomic, assign) int logCacheLimitCount;
/// logging 类型数据超过最大值后是否废弃最新数据
@property (atomic, assign) BOOL logDiscardNew;
@property (atomic, assign) int  rumCacheLimitCount;
/// logging 类型数据超过最大值后是否废弃最新数据
@property (atomic, assign) BOOL rumDiscardNew;

- (void)setLogCacheLimitCount:(int)count logDiscardNew:(BOOL)discardNew;
- (void)setRumCacheLimitCount:(int)count logDiscardNew:(BOOL)discardNew;
- (void)addLogData:(id)data;
- (void)addRumData:(id)data;
/// 判断日志存储是否到达容量一半
- (BOOL)reachLogHalfLimit;
- (BOOL)reachRumHalfLimit;
- (void)insertCacheToDB;
@end

NS_ASSUME_NONNULL_END
