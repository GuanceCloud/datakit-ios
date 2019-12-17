//
//  ZYSQLite3.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYTrackerEventDBTool.h"
#import "RecordModel.h"
#import "ZY_FMDB.h"
#import "ZYLog.h"
@interface ZYTrackerEventDBTool ()
@property (nonatomic, strong)NSString *dbPath;
@property (nonatomic, strong)ZY_FMDatabaseQueue *dbQueue;
@property (nonatomic, strong)ZY_FMDatabase *db;

@end
@implementation ZYTrackerEventDBTool
static ZYTrackerEventDBTool *dbTool = nil;
- (ZY_FMDatabaseQueue *)dbQueue
{
    if (!_dbQueue) {
        ZY_FMDatabaseQueue *fmdb = [ZY_FMDatabaseQueue databaseQueueWithPath:_dbPath];
        self.dbQueue = fmdb;
        [_db close];
        self.db = [fmdb valueForKey:@"_db"];
    }
    return _dbQueue;
}
#pragma mark --创建数据库
+ (instancetype)sharedManger {
    if (!dbTool) {
        NSString  *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZYFMDB.sqlite"];
        ZY_FMDatabase *fmdb = [ZY_FMDatabase databaseWithPath:path];
        if ([fmdb open]) {
            dbTool = ZYTrackerEventDBTool.new;
            dbTool.db = fmdb;
            dbTool.dbPath = path;
            ZYDebug(@"db path:%@",path);
        }
    }
    if (![dbTool.db open]) {
        ZYDebug(@"database can not open !");
        return nil;
    };
    return dbTool;
}
-(void)createTable
{
    if ([self zy_isExistTable:ZY_DB_BASELOG_TABLE_NAME]) {
        return;
    }
      [self zy_inTransaction:^(BOOL *rollback) {
        NSDictionary *keyTypes = @{@"_id":@"INTEGER",
                                   @"tm":@"INTEGER",
                                   @"data":@"TEXT",
        };
        if ([self isOpenDatabese:self.db]) {
               NSMutableString *sql = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (",ZY_DB_BASELOG_TABLE_NAME]];
               int count = 0;
               for (NSString *key in keyTypes) {
                   count++;
                   [sql appendString:key];
                   [sql appendString:@" "];
                   [sql appendString:[keyTypes valueForKey:key]];
                   if ([key isEqualToString:@"_id"]) {
                       [sql appendString:@" primary key AUTOINCREMENT"];
                   }
                   if (count != [keyTypes count]) {
                        [sql appendString:@", "];
                   }
               }
               [sql appendString:@")"];
               ZYDebug(@"%@", sql);
             BOOL success =[self.db executeUpdate:sql];
            ZYDebug(@"createTable success == %d",success);
           }
    }];
}
-(BOOL)insertItemWithItemData:(RecordModel *)item{
   if([self isOpenDatabese:self.db]) {
       __block BOOL  is = NO;
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data') VALUES (  '%ld' , '%@' );",ZY_DB_BASELOG_TABLE_NAME,item.tm,item.data];
          is=  [self.db executeUpdate:sqlStr];
           ZYDebug(@"success == %d",is);
       }];
       return is;
   }else{
   return NO;
   }
}

-(NSArray *)getAllDatas{
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' ORDER BY tm ASC  ;",ZY_DB_BASELOG_TABLE_NAME];

    return [self getDatasWithFormat:sql];

}
-(NSArray *)getFirstTenData{
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' ORDER BY tm ASC limit 10  ;",ZY_DB_BASELOG_TABLE_NAME];

    return [self getDatasWithFormat:sql];
}
-(NSArray *)getDatasWithFormat:(NSString *)format{
 if([self isOpenDatabese:self.db]) {
     __block  NSMutableArray *array = [NSMutableArray new];
  [self zy_inDatabase:^{
      //ORDER BY ID DESC --根据ID降序查找:ORDER BY ID ASC --根据ID升序序查找
      ZY_FMResultSet*set = [self.db executeQuery:format];
      while(set.next) {

      //创建对象赋值

      RecordModel* item = [[RecordModel alloc]init];

      item._id= [[set stringForColumn:@"_id"]intValue];

      item.tm= [[set stringForColumn:@"tm"] longLongValue];

      item.data= [set stringForColumn:@"data"];

      [array addObject:item];

      }
      }];
        return array;
    }else{
        return nil;
    }
}
- (NSInteger)getDatasCount
{
    __block NSInteger count =0;
    [self zy_inDatabase:^{
        NSString *sqlstr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", ZY_DB_BASELOG_TABLE_NAME];
          ZY_FMResultSet *set = [self.db executeQuery:sqlstr];

          while ([set next]) {
              count= [set intForColumn:@"count"];
          }

    }];
     return count;
}
-(BOOL)deleteItemWithTm:(long )tm
{   __block BOOL is;
    [self zy_inDatabase:^{
     NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE tm <= %ld ;",ZY_DB_BASELOG_TABLE_NAME,tm];
        is = [self.db executeUpdate:sqlStr];
    }];
    return is;
}
- (void)close
{
    [_db close];
}
-(BOOL)isOpenDatabese:(ZY_FMDatabase *)db{
    if (![db open]) {
        [db open];
    }
    return YES;
}
- (BOOL)zy_isExistTable:(NSString *)tableName
{
    __block NSInteger count = 0;
    [self zy_inDatabase:^{
        ZY_FMResultSet *set = [self.db executeQuery:@"SELECT count(*) as 'count' FROM sqlite_master "
                                                "WHERE type ='table' and name = ?", tableName];
           while([set next]) {
               count = [set intForColumn:@"count"];
           }
           [set close];
    }];
   
    return count > 0;
}
- (void)zy_inDatabase:(void(^)(void))block
{

    [[self dbQueue] inDatabase:^(ZY_FMDatabase *db) {
        block();
    }];
}

- (void)zy_inTransaction:(void(^)(BOOL *rollback))block
{

    [[self dbQueue] inTransaction:^(ZY_FMDatabase *db, BOOL *rollback) {
        block(rollback);
    }];

}

@end
