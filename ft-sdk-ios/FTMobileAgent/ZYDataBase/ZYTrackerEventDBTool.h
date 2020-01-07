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

-(BOOL)insertUserDataWithName:(NSString *)name Id:(NSString *)Id exts:(NSDictionary *)exts;
@end
NS_ASSUME_NONNULL_END
