//
//  FTLogDataCache.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/17.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import <Foundation/Foundation.h>
#import "FTUploadProtocol.h"
NS_ASSUME_NONNULL_BEGIN
typedef void (^LogDataWriteDBCallback)(void);

@interface FTDBDataCachePolicy : NSObject<FTUploadCountProtocol>

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
- (void)insertCacheToDBWithoutCallback;
@end

NS_ASSUME_NONNULL_END
