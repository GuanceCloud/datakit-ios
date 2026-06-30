//
//  ZYSQLite3.h
//  FTMobileAgent
//
//  Created by hulilei on 2019/12/2.
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

NS_ASSUME_NONNULL_BEGIN
#define FT_DB_TRACE_EVENT_TABLE_NAME @"trace_event"
@class FTRecordModel;

/// Tool for operating database data
@interface FTTrackerEventDBTool : NSObject
/// Singleton
+ (nullable FTTrackerEventDBTool *)sharedManager;
/// Singleton
/// @param enableLimitWithDbSize whether to enable DB size limit related storage recovery
+ (nullable FTTrackerEventDBTool *)sharedManagerWithEnableLimitWithDbSize:(BOOL)enableLimitWithDbSize;
/// Singleton
/// @param dbPath database path
/// @param dbName database name
+ (nullable FTTrackerEventDBTool *)shareDatabaseWithPath:(nullable NSString *)dbPath dbName:(nullable NSString *)dbName;

/// Add an object to the database
/// @param item data to be recorded
-(BOOL)insertItem:(FTRecordModel *)item;

/// Add a group of objects to the database
/// @param items data to be recorded
-(BOOL)insertItemsWithDatas:(NSArray<FTRecordModel*> *)items;

/// Get all data from the database
-(NSArray *)getAllDatas;

/// Get data from the front end of the database according to specified type and quantity
/// @param recordSize number of data records to get
/// @param type data type
-(NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type;
/// Delete uploaded data according to type
/// @param type data type
/// @param identify delete data before this _id
-(BOOL)deleteItemWithType:(NSString *)type identify:(NSString *)identify count:(NSInteger)count;

/// Delete all data
-(BOOL)deleteAllDatas;

/// Delete log data
/// @param count delete the first count data
-(BOOL)deleteDataWithType:(NSString *)type count:(NSInteger)count;

-(BOOL)deleteDataWithCount:(NSInteger)count;
-(BOOL)deleteUploadDataWithCount:(NSInteger)count;

- (BOOL)deleteDatasWithType:(NSString *)type;

- (BOOL)deleteDatasWithType:(NSString *)type toTime:(long long)toTime;
- (BOOL)deleteDatasWithType:(NSString *)type fromTime:(long long)fromTime toTime:(long long)toTime;

- (BOOL)updateDatasWithType:(NSString *)type toType:(NSString *)toType toTime:(long long)toTime;
- (BOOL)updateDatasWithType:(NSString *)type toType:(NSString *)toType fromTime:(long long)fromTime toTime:(long long)toTime;
/// Get total number of database data
- (NSInteger)getDatasCount;

- (NSInteger)getUploadDatasCount;

/// Get total number of database data of a certain type
/// @param type data type
- (NSInteger)getDatasCountWithType:(NSString *)type;

- (long long)checkDatabaseSize;

/// close db
- (void)close;
@end
NS_ASSUME_NONNULL_END
