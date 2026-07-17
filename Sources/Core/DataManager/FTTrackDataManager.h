//
//  FTTrackDataManager.h
//  FTSDK
//
//  Created by hulilei on 2021/8/4.
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

#import <Foundation/Foundation.h>
#import "FTDataWriterWorker.h"
/// Data addition type
typedef NS_ENUM(NSInteger, FTAddDataType) {
    ///rum
    FTAddDataRUM,
    ///logging
    FTAddDataLogging,
    ///rumCache,
    FTAddDataRUMCache
};
NS_ASSUME_NONNULL_BEGIN
@class FTRecordModel,FTDataWriterWorker,FTHTTPClient;
@protocol FTRUMDataWriteProtocol;
/// Data writing and data uploading related operations
@interface FTTrackDataManager : NSObject
@property (atomic, assign, readonly) BOOL autoSync;

@property (nonatomic, strong) FTHTTPClient *httpClient;

@property (nonatomic, strong) FTDataWriterWorker *dataWriterWorker;

/// Singleton
+(instancetype)sharedInstance;

+(instancetype)startWithAutoSync:(BOOL)autoSync
                    syncPageSize:(int)syncPageSize
                   syncSleepTime:(int)syncSleepTime;
- (void)updateAutoSync:(BOOL)autoSync
          syncPageSize:(int)syncPageSize
         syncSleepTime:(int)syncSleepTime;

- (void)enableAutoSync:(BOOL)autoSync;

- (void)setEnableLimitWithDb:(BOOL)enable size:(long)size discardNew:(BOOL)discardNew;
- (void)setLogCacheLimitCount:(int)count discardNew:(BOOL)discardNew;
- (void)setRUMCacheLimitCount:(int)count discardNew:(BOOL)discardNew;

 /// Data writing
/// - Parameters:
///   - data: data
///   - type: data storage type
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type;

/// Upload data
- (void)flushSyncData;


/// Add cached data to database
-(void)insertCacheToDB;

/// Shut down singleton
+ (void)shutDown;

@end

NS_ASSUME_NONNULL_END
