//
//  ZYSQLite3.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTTrackerEventDBTool.h"
#import "ZY_FMDB.h"
#import "FTRecordModel.h"
#import "FTLog+Private.h"
#import "FTConstants.h"
#import <pthread.h>
#import "FTSDKCompat.h"
@interface FTTrackerEventDBTool ()
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) ZY_FMDatabaseQueue *dbQueue;
@property (nonatomic, strong) ZY_FMDatabase *db;
@property (nonatomic, strong) NSMutableArray<FTRecordModel *> *messageCaches;

@end
@implementation FTTrackerEventDBTool{
    pthread_mutex_t _lock;

}
static FTTrackerEventDBTool *dbTool = nil;
static dispatch_once_t onceToken;

#pragma mark --创建数据库
+ (instancetype)sharedManger
{
    return [FTTrackerEventDBTool shareDatabaseWithPath:nil dbName:nil];
}
+ (instancetype)shareDatabaseWithPath:(NSString *)dbPath dbName:(NSString *)dbName{
    dispatch_once(&onceToken, ^{
    if (!dbTool) {
        NSString *path = dbPath;
        NSString *name = dbName;
        if (!path) {
            path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        }
        if(!name){
            name = @"ZYFMDB.sqlite";
        }
        path = [path stringByAppendingPathComponent:name];
        ZY_FMDatabaseQueue *dbQueue = [ZY_FMDatabaseQueue databaseQueueWithPath:path];
        ZY_FMDatabase *fmdb = [dbQueue valueForKey:@"_db"];
        if ([fmdb  open]) {
            dbTool = [[FTTrackerEventDBTool alloc]init];
            dbTool.db = fmdb;
            dbTool.dbPath = path;
            FTInnerLogDebug(@"db path:%@",path);
            dbTool.dbQueue = dbQueue;
            dbTool.logCacheLimitCount = FT_DB_CONTENT_MAX_COUNT;
        }
        pthread_mutex_init(&(dbTool->_lock), NULL);
        [dbTool createTable];
     }
    });
    if (![dbTool.db open]) {
        FTInnerLogError(@"database can not open !");
        return nil;
    };
    return dbTool;
}
- (void)createTable{
    @try {
        [self createEventTable];
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@",exception);
    }
}
-(void)createEventTable
{
    if ([self zy_isExistTable:FT_DB_TRACE_EVENT_TABLE_NAME]) {
        return;
    }
      [self zy_inTransaction:^(BOOL *rollback) {
        NSDictionary *keyTypes = @{@"_id":@"INTEGER",
                                   @"tm":@"INTEGER",
                                   @"data":@"TEXT",
                                   @"op":@"TEXT",
        };
        if ([self isOpenDatabase:self.db]) {
               NSMutableString *sql = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (",FT_DB_TRACE_EVENT_TABLE_NAME]];
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
             BOOL success =[self.db executeUpdate:sql];
            FTInnerLogDebug(@"createTable success == %d",success);
           }
    }];
}

-(BOOL)insertItem:(FTRecordModel *)item{
    __block BOOL success = NO;
   if([self isOpenDatabase:self.db]) {
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data' ,'op') VALUES (  ? , ? , ? );",FT_DB_TRACE_EVENT_TABLE_NAME];
          success=  [self.db executeUpdate:sqlStr,@(item.tm),item.data,item.op];
       }];
   }
    return success;
}
-(void)insertLoggingItems:(FTRecordModel *)item{
    if (!item) {
        return;
    }
    pthread_mutex_lock(&_lock);
    [self.messageCaches addObject:item];
    if (self.messageCaches.count>=20) {
        NSInteger count = self.logCacheLimitCount - [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_LOGGING]-self.messageCaches.count;
        
        if(count < 0){
            if(!self.discardNew){
                [[FTTrackerEventDBTool sharedManger] deleteLoggingItem:-count];
            }else{
                NSInteger sum = count+self.messageCaches.count;
                if (sum>=0) {
                    [self.messageCaches removeObjectsInRange:NSMakeRange(sum, self.messageCaches.count-sum)];
                }
            }
        }
        [self insertItemsWithDatas:self.messageCaches];
        [self.messageCaches removeAllObjects];
    }
    pthread_mutex_unlock(&_lock);

}
-(BOOL)insertItemsWithDatas:(NSArray<FTRecordModel*> *)items{
    __block BOOL needRollback = NO;
    if([self isOpenDatabase:self.db]) {
        [self zy_inTransaction:^(BOOL *rollback) {
            [items enumerateObjectsUsingBlock:^(FTRecordModel *item, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data','op') VALUES (  ? , ? , ? );",FT_DB_TRACE_EVENT_TABLE_NAME];
                if(![self.db executeUpdate:sqlStr,@(item.tm),item.data,item.op]){
                    *stop = YES;
                    needRollback = YES;
                }
            }];
            *rollback = needRollback;
        }];
        
    }
    return !needRollback;
}
-(void)insertCacheToDB{
    pthread_mutex_lock(&_lock);
    if (self.messageCaches.count > 0) {
        NSArray *array = [self.messageCaches copy];
        self.messageCaches = nil;
        pthread_mutex_unlock(&_lock);
        [self insertItemsWithDatas:array];
    }else{
        pthread_mutex_unlock(&_lock);
    }
}
-(NSArray *)getAllDatas{
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' ORDER BY tm ASC  ;",FT_DB_TRACE_EVENT_TABLE_NAME];

    return [self getDatasWithFormat:sql];

}

-(NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type{
    if (recordSize == 0) {
        return @[];
    }
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' WHERE op = '%@' ORDER BY _id ASC limit %lu  ;",FT_DB_TRACE_EVENT_TABLE_NAME,type,(unsigned long)recordSize];

    return [self getDatasWithFormat:sql];
}

-(NSArray *)getDatasWithFormat:(NSString *)format{
    if([self isOpenDatabase:self.db]) {
        __block  NSMutableArray *array = [NSMutableArray new];
        [self zy_inDatabase:^{
            //ORDER BY ID DESC --根据ID降序查找:ORDER BY ID ASC --根据ID升序序查找
            ZY_FMResultSet*set = [self.db executeQuery:format];
            while(set.next) {
                //创建对象赋值
                FTRecordModel* item = [[FTRecordModel alloc]init];
                item.tm = [set longForColumn:@"tm"];
                item.data= [set stringForColumn:@"data"];
                item.op = [set stringForColumn:@"op"];
                item._id = [set stringForColumn:@"_id"];
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
        NSString *sqlStr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", FT_DB_TRACE_EVENT_TABLE_NAME];
          ZY_FMResultSet *set = [self.db executeQuery:sqlStr];

          while ([set next]) {
              count= [set intForColumn:@"count"];
          }

    }];
     return count;
}
- (NSInteger)getDatasCountWithType:(NSString *)op{
    __block NSInteger count =0;
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@ WHERE op = '%@'", FT_DB_TRACE_EVENT_TABLE_NAME,op];
             ZY_FMResultSet *set = [self.db executeQuery:sqlStr];

             while ([set next]) {
                 count= [set intForColumn:@"count"];
             }

       }];
        return count;
    
}
-(BOOL)deleteItemWithType:(NSString *)type tm:(long long)tm{
    __block BOOL is;
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE op = '%@' AND tm <= %lld ;",FT_DB_TRACE_EVENT_TABLE_NAME,type,tm];
           is = [self.db executeUpdate:sqlStr];
       }];
       return is;
}
-(BOOL)deleteItemWithType:(NSString *)type identify:(NSString *)identify{
    __block BOOL is;
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE op = '%@' AND _id <= %@ ;",FT_DB_TRACE_EVENT_TABLE_NAME,type,identify];
           is = [self.db executeUpdate:sqlStr];
       }];
       return is;
}
-(BOOL)deleteLoggingItem:(NSInteger)count{
    __block BOOL is;
        [self zy_inDatabase:^{
            NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE op = '%@' AND (select count(_id) FROM '%@')> %ld AND _id IN (select _id FROM '%@' ORDER BY _id ASC limit %ld) ;",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DATA_TYPE_LOGGING,FT_DB_TRACE_EVENT_TABLE_NAME,(long)count,FT_DB_TRACE_EVENT_TABLE_NAME,(long)count];
            is = [self.db executeUpdate:sqlStr];
        }];
        return is;
}
-(BOOL)deleteItemWithTm:(long long)tm
{   __block BOOL is;
    [self zy_inDatabase:^{
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE tm <= %lld ;",FT_DB_TRACE_EVENT_TABLE_NAME,tm];
        is = [self.db executeUpdate:sqlStr];
    }];
    return is;
}
//-(BOOL)deleteItemWithId:(long )Id
//{   __block BOOL is;
//    [self zy_inDatabase:^{
//     NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE _id <= %ld ;",FT_DB_TRACE_EVENT_TABLE_NAME,Id];
//        is = [self.db executeUpdate:sqlStr];
//    }];
//    return is;
//}
- (void)close
{
    [_db close];
}
-(BOOL)isOpenDatabase:(ZY_FMDatabase *)db{
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
- (NSMutableArray<FTRecordModel *> *)messageCaches {
    if (!_messageCaches) {
        _messageCaches = [NSMutableArray array];
    }
    return _messageCaches;
}
- (void)shutDown{
    [self insertCacheToDB];
    onceToken = 0;
    dbTool = nil;
}
@end
