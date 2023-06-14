//
//  ZYSQLite3.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#define FT_DB_TRACREVENT_TABLE_NAME @"trace_event"
@class FTRecordModel;
/// 操作数据库数据的工具
@interface FTTrackerEventDBTool : NSObject
/// logging 类型数据超过最大值后是否废弃最新数据
@property (nonatomic, assign) BOOL discardNew;
/// 数据库中 logging 类型数据最大数量
@property (nonatomic, assign) NSInteger dbLoggingMaxCount;
/// 单例
+ (FTTrackerEventDBTool *)sharedManger;
/// 单例
/// @param dbPath 数据库地址
/// @param dbName 数据库名称
+ (FTTrackerEventDBTool *)shareDatabaseWithPath:(nullable NSString *)dbPath dbName:(nullable NSString *)dbName;
/**
 * @abstract
 * 向数据库中添加一个对象
 *
 * @param item 要记录的数据
 * @return 存储是否成功
 */
-(BOOL)insertItem:(FTRecordModel *)item;
/**
 * @abstract
 * 向数据库中添加一组对象
 *
 * @param items 要记录的数据
 * @return 存储是否成功
 */
-(BOOL)insertItemsWithDatas:(NSArray<FTRecordModel*> *)items;
/**
 * @abstract
 * 向日志缓存中添加一组对象
 *
 * @param data 要记录的数据
 */
-(void)insertLoggingItems:(FTRecordModel *)data;
/**
*  @abstract
*  缓存中的数据添加到数据库中
*/
-(void)insertCacheToDB;
/**
 * @abstract
 * 获取数据库所有的数据
 *
 * @return 获取的数据
 */
-(NSArray *)getAllDatas;
/**
 * @abstract
 * 从数据库前端，获取前多少条记录
 *
 * @param recordSize 获取记录数
 * @param type 数据类型
 * @return 获取的数据
 */
-(NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type;
/**
 * @abstract
 * 根据类型删除已上传的数据
 *
 * @param type 数据类型
 * @param tm 删除在此时间之前的数据
 * @return 删除是否成功
 */
-(BOOL)deleteItemWithType:(NSString *)type tm:(long long)tm;
/**
 * @abstract
 * 根据类型删除已上传的数据
 *
 * @param type 数据类型
 * @param identify 删除在此 _id 之前的数据
 * @return 删除是否成功
 */
-(BOOL)deleteItemWithType:(NSString *)type identify:(NSString *)identify;
/**
 * @abstract
 * 删除已上传的数据
 *
 * @param tm 删除在此时间之前的数据
 * @return 删除是否成功
 */
-(BOOL)deleteItemWithTm:(long long)tm;
/**
 * @abstract
 * 删除日志数据
 *
 * @param count 删除前 count 个数据
 * @return 删除是否成功
 */
-(BOOL)deleteLoggingItem:(NSInteger)count;
/**
 * @abstract
 * 获取数据库数据总数
 *
 * @return 数据数量
 */
- (NSInteger)getDatasCount;
/**
 * @abstract
 * 获取数据库某类型数据总数
 *
 * @param type 数据类型
 * @return 数据数量
 */
- (NSInteger)getDatasCountWithType:(NSString *)type;

@end
NS_ASSUME_NONNULL_END
