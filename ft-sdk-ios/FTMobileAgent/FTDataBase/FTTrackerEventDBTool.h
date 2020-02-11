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
#define FT_DB_USERSESSION_TABLE_NAME    @"user_session_data"
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
-(BOOL)insertItemWithItemData:(FTRecordModel *)datas;
/**
*  @abstract
*  获取数据库所有的数据 不绑定用户信息

*  @return 获取的数据
*/
-(NSArray *)getAllDatas;
/**
*  @abstract
*  从数据库前端，获取十条记录，获取的记录以FTRecordModel的形式存放在数组中 包含相应的用户信息 未绑定用户时无法获取数据

*  @return 获取的数据
*/
-(NSArray *)getFirstTenData;
/**
*  @abstract
*  删除已上传的数据
*  @param tm 删除在此时间之前的数据

*  @return 删除是否成功
*/
-(BOOL)deleteItemWithTm:(long )tm;
/**
*  @abstract
*  获取数据库数据总数
 
*  @return 数据数量
*/
- (NSInteger)getDatasCount;
/**
*  @abstract
*  添加用户
*  @param name 用户名
*  @param Id 用户Id
*  @param exts 用户额外的数据
 
*  @return 数据数量
*/
-(BOOL)insertUserDataWithName:(NSString *)name Id:(NSString *)Id exts:(NSDictionary *)exts;
@end
NS_ASSUME_NONNULL_END
