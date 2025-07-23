//
//  FTLogDataCache.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTUploadProtocol.h"
NS_ASSUME_NONNULL_BEGIN
typedef void (^LogDataWriteDBCallback)(void);

@interface FTDBDataCachePolicy : NSObject<FTUploadCountProtocol>
@property (atomic, assign) NSInteger logCount;
@property (atomic, assign) NSInteger rumCount;
@property (atomic, assign) long currentDbSize;
@property (nonatomic, assign) BOOL dbDiscardNew;
@property (nonatomic, copy, nullable) LogDataWriteDBCallback callback;

- (void)setDBLimitWithSize:(long)size discardNew:(BOOL)discardNew;
- (void)setLogCacheLimitCount:(int)count discardNew:(BOOL)discardNew;
- (void)setRumCacheLimitCount:(int)count discardNew:(BOOL)discardNew;
- (void)addLogData:(id)data;
- (BOOL)addRumData:(id)data;
/// Determine whether log storage has reached half capacity
- (BOOL)reachHalfLimit;
- (void)insertCacheToDB;
@end

NS_ASSUME_NONNULL_END
