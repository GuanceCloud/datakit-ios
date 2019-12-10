//
//  ZYSQLite3.h
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZY_FMDB.h"
NS_ASSUME_NONNULL_BEGIN
#define ZY_DB_BASELOG_TABLE_NAME @"zy_base"
@class RecordModel;
@interface ZYTrackerEventDBTool : NSObject

+(ZYTrackerEventDBTool *)sharedManger;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (id)copy NS_UNAVAILABLE; // 没有遵循协议可以不写
- (id)mutableCopy NS_UNAVAILABLE; // 没有遵循协议可以不写

-(void)createTable;
-(BOOL)insertItemWithItemData:(RecordModel *)datas;
-(NSArray *)getAllDatas;
-(NSArray *)getFirstTenData;
-(BOOL)deleteItemWithTm:(long )tm;
- (NSInteger)getDatasCount;
@end
NS_ASSUME_NONNULL_END
