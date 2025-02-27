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
@property (atomic, assign) long currentDbSize;
@property (nonatomic, assign) BOOL dbDiscardNew;

- (void)setDBLimitWithSize:(long)size discardNew:(BOOL)discardNew;
- (void)setLogCacheLimitCount:(int)count discardNew:(BOOL)discardNew;
- (void)setRumCacheLimitCount:(int)count discardNew:(BOOL)discardNew;
- (void)addLogData:(id)data;
- (void)addRumData:(id)data;
/// 判断日志存储是否到达容量一半
- (BOOL)reachHalfLimit;
- (void)insertCacheToDB;
@end

NS_ASSUME_NONNULL_END
