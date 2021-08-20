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
@interface FTTrackerEventDBTool : NSObject

+(FTTrackerEventDBTool *)sharedManger;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (id)copy NS_UNAVAILABLE; // 没有遵循协议可以不写
- (id)mutableCopy NS_UNAVAILABLE; // 没有遵循协议可以不写
/**
*  @abstract
*  向数据库中添加一个对象
*
*  @param datas 要记录的数据
*
*  @return 存储是否成功
*/
-(BOOL)insertItem:(FTRecordModel *)datas;
/**
*  @abstract
*  向数据库中添加一组对象
*
*  @param items 要记录的数据
*
*  @return 存储是否成功
*/
-(BOOL)insertItemWithItemDatas:(NSArray<FTRecordModel*> *)items;
/**
*  @abstract
*  向缓存中添加一组对象
*
*  @param data 要记录的数据
*
*/
-(void)insertItemToCache:(FTRecordModel *)data;
/**
*  @abstract
*  缓存中的数据添加到数据库中
*/
-(void)insertCacheToDB;
/**
*  @abstract
*  获取数据库所有的数据

*  @return 获取的数据
*/
-(NSArray *)getAllDatas;
/**
*  @abstract
*  从数据库前端，获取十条记录

*  @return 获取的数据
*/
-(NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type;
/**
*  @abstract
*  根据类型删除已上传的数据
*  @param tm 删除在此时间之前的数据

*  @return 删除是否成功
*/
-(BOOL)deleteItemWithType:(NSString *)type tm:(long long)tm;
/**
*  @abstract
*  删除已上传的数据
*  @param tm 删除在此时间之前的数据

*  @return 删除是否成功
*/
-(BOOL)deleteItemWithTm:(long long)tm;
/**
*  @abstract
*  获取数据库数据总数
 
*  @return 数据数量
*/
- (NSInteger)getDatasCount;
/**
*  @abstract
*  获取数据库某类型数据总数
 
*  @return 数据数量
*/
- (NSInteger)getDatasCountWithOp:(NSString *)op;

@end
NS_ASSUME_NONNULL_END
