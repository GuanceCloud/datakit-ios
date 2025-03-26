//
//  ZYSQLite3.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#define FT_DB_TRACE_EVENT_TABLE_NAME @"trace_event"
@class FTRecordModel;

/// 操作数据库数据的工具
@interface FTTrackerEventDBTool : NSObject
/// 单例
+ (nullable FTTrackerEventDBTool *)sharedManger;
/// 单例
/// @param dbPath 数据库地址
/// @param dbName 数据库名称
+ (nullable FTTrackerEventDBTool *)shareDatabaseWithPath:(nullable NSString *)dbPath dbName:(nullable NSString *)dbName;

/// 向数据库中添加一个对象
/// @param item 要记录的数据
-(BOOL)insertItem:(FTRecordModel *)item;

/// 向数据库中添加一组对象
/// @param items 要记录的数据
-(BOOL)insertItemsWithDatas:(NSArray<FTRecordModel*> *)items;

/// 获取数据库所有的数据
-(NSArray *)getAllDatas;

/// 根据指定类型、数量获取从数据库前端获取数据
/// @param recordSize 获取数据条数
/// @param type 数据类型
-(NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type;
/// 根据类型删除已上传的数据
/// @param type 数据类型
/// @param identify 删除在此 _id 之前的数据
-(BOOL)deleteItemWithType:(NSString *)type identify:(NSString *)identify count:(NSInteger)count;

/// 删除所有数据
-(BOOL)deleteAllDatas;

/// 删除日志数据
/// @param count 删除前 count 个数据
-(BOOL)deleteDataWithType:(NSString *)type count:(NSInteger)count;

-(BOOL)deleteDataWithCount:(NSInteger)count;

- (BOOL)deleteDatasWithType:(NSString *)type;

- (BOOL)deleteDatasWithType:(NSString *)type time:(long long)time;

- (BOOL)updateDatasWithType:(NSString *)type toType:(NSString *)toType time:(long long)time;
/// 获取数据库数据总数
- (NSInteger)getDatasCount;

/// 获取数据库某类型数据总数
/// @param type 数据类型
- (NSInteger)getDatasCountWithType:(NSString *)type;

- (long)checkDatabaseSize;

- (void)setEnableLimitWithDbSize:(BOOL)enableLimitWithDbSize;
/// 关闭单例
- (void)shutDown;
@end
NS_ASSUME_NONNULL_END
