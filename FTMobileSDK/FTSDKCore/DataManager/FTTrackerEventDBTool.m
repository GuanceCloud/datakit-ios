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
#import "FTSDKCompat.h"
@interface FTTrackerEventDBTool ()
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) ZY_FMDatabaseQueue *dbQueue;
@property (nonatomic, assign) BOOL enableLimitWithDbSize;

@end
@implementation FTTrackerEventDBTool
static FTTrackerEventDBTool *dbTool = nil;
static dispatch_once_t onceToken;

#pragma mark --创建数据库
+ (instancetype)sharedManger
{
    return [FTTrackerEventDBTool shareDatabaseWithPath:nil dbName:nil];
}
+ (instancetype)shareDatabaseWithPath:(NSString *)dbPath dbName:(NSString *)dbName{
    dispatch_once(&onceToken, ^{
        NSString *path = dbPath;
        NSString *name = dbName;
        if (!path) {
#if !TARGET_OS_TV
            path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
#else
            path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
#endif
        }
        if(!name){
            name = @"ZYFMDB.sqlite";
        }
        path = [path stringByAppendingPathComponent:name];
        ZY_FMDatabaseQueue *dbQueue = [ZY_FMDatabaseQueue databaseQueueWithPath:path];
        if (dbQueue) {
            dbTool = [[FTTrackerEventDBTool alloc]init];
            dbTool.dbPath = path;
            FTInnerLogDebug(@"db path:%@",path);
            dbTool.dbQueue = dbQueue;
            dbTool.enableLimitWithDbSize = NO;
            [dbTool createTable];
        }
    });
    if (!dbTool) {
        FTInnerLogError(@"database can not open !");
        onceToken = 0;
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
-(void)createEventTable{
    if ([self zy_isExistTable:FT_DB_TRACE_EVENT_TABLE_NAME]) {
        return;
    }
    [[self dbQueue] inTransaction:^(ZY_FMDatabase *db, BOOL *rollback) {
        NSDictionary *keyTypes = @{@"_id":@"INTEGER",
                                   @"tm":@"INTEGER",
                                   @"data":@"TEXT",
                                   @"op":@"TEXT",
        };
        
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
        BOOL success =[db executeUpdate:sql];
        FTInnerLogDebug(@"createTable success == %d",success);
    }];
}

-(BOOL)insertItem:(FTRecordModel *)item{
    __block BOOL success = NO;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data' ,'op') VALUES (  ? , ? , ? );",FT_DB_TRACE_EVENT_TABLE_NAME];
        success=  [db executeUpdate:sqlStr,@(item.tm),item.data,item.op];
    }];
    return success;
}
-(BOOL)insertItemsWithDatas:(NSArray<FTRecordModel*> *)items{
    if(items.count>0){
        __block BOOL needRollback = NO;
        [[self dbQueue] inTransaction:^(ZY_FMDatabase *db, BOOL *rollback) {
            [items enumerateObjectsUsingBlock:^(FTRecordModel *item, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data','op') VALUES (  ? , ? , ? );",FT_DB_TRACE_EVENT_TABLE_NAME];
                if(![db executeUpdate:sqlStr,@(item.tm),item.data,item.op]){
                    *stop = YES;
                    needRollback = YES;
                }
            }];
            *rollback = needRollback;
        }];
        return !needRollback;
    }
    return NO;
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
    __block  NSMutableArray *array = [NSMutableArray new];
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        //ORDER BY ID DESC --根据ID降序查找:ORDER BY ID ASC --根据ID升序序查找
        ZY_FMResultSet*set = [db executeQuery:format];
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
}
- (NSInteger)getDatasCount{
    __block NSInteger count =0;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", FT_DB_TRACE_EVENT_TABLE_NAME];
        ZY_FMResultSet *set = [db executeQuery:sqlStr];
        while ([set next]) {
            count= [set intForColumn:@"count"];
        }
    }];
    return count;
}
- (NSInteger)getDatasCountWithType:(NSString *)op{
    __block NSInteger count =0;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@ WHERE op = '%@'", FT_DB_TRACE_EVENT_TABLE_NAME,op];
        ZY_FMResultSet *set = [db executeQuery:sqlStr];
        while ([set next]) {
            count= [set intForColumn:@"count"];
        }
    }];
    return count;
}
-(BOOL)deleteItemWithType:(NSString *)type identify:(NSString *)identify count:(NSInteger)count{
    __block BOOL is;
    __weak __typeof(self) weakSelf = self;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE op = '%@' AND _id <= %@ ;",FT_DB_TRACE_EVENT_TABLE_NAME,type,identify];
        is = [db executeUpdate:sqlStr];
        if(weakSelf.enableLimitWithDbSize){
            NSString *str = [NSString stringWithFormat:@"PRAGMA incremental_vacuum(%ld)",(long)count];
            [db executeUpdate:str];
        }
    }];
    return is;
}
-(BOOL)deleteDataWithType:(NSString *)type count:(NSInteger)count{
    __block BOOL is;
    __weak __typeof(self) weakSelf = self;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE _id in (SELECT _id from '%@' WHERE  op = '%@' ORDER by _id ASC LIMIT '%ld' )",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_TRACE_EVENT_TABLE_NAME,type,(long)count];
        is = [db executeUpdate:sqlStr];
        if(weakSelf.enableLimitWithDbSize){
            NSString *str = [NSString stringWithFormat:@"PRAGMA incremental_vacuum(%ld)",(long)count];
            [db executeUpdate:str];
        }
    }];
    return is;
}
-(BOOL)deleteDataWithCount:(NSInteger)count{
    __block BOOL is;
    __weak __typeof(self) weakSelf = self;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE _id in (SELECT _id from '%@' ORDER by _id ASC LIMIT '%ld')",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_TRACE_EVENT_TABLE_NAME,(long)count];
        is = [db executeUpdate:sqlStr];
        if(weakSelf.enableLimitWithDbSize){
            NSString *str = [NSString stringWithFormat:@"PRAGMA incremental_vacuum(%ld)",(long)count];
            [db executeUpdate:str];
        }
    }];
    return is;
}
-(BOOL)deleteAllDatas{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@';",FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr];
    }];
    [self close];
    return is;
}
- (BOOL)deleteDatasWithType:(NSString *)type{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE  op = '%@' ",FT_DB_TRACE_EVENT_TABLE_NAME,type];
        is = [db executeUpdate:sqlStr];
    }];
    return is;
}
- (BOOL)deleteDatasWithType:(NSString *)type time:(long long)time{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE _id in (SELECT _id from '%@' WHERE  op = '%@' AND tm < '%lld' )",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_TRACE_EVENT_TABLE_NAME,type,time];
        is = [db executeUpdate:sqlStr];
    }];
    return is;
}
- (BOOL)updateDatasWithType:(NSString *)type toType:(NSString *)toType time:(long long)time{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"UPDATE '%@' SET op = '%@'  WHERE tm < '%lld' AND op = '%@'",FT_DB_TRACE_EVENT_TABLE_NAME,toType,time,type];
        is = [db executeUpdate:sqlStr];
    }];
    return is;
}
- (void)close{
    [self vacuumDB];
    [[self dbQueue] close];
}
static long pageSize = 0;
- (long)checkDatabaseSize{
    __block long fileSize = -1;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        if(pageSize<=0){
            ZY_FMResultSet *set = [db executeQuery:@"PRAGMA page_size;"];
            while([set next]) {
                pageSize = [set longForColumn:@"page_size"];
            }
            [set close];
        }
        ZY_FMResultSet *countSet = [db executeQuery:@"PRAGMA page_count;"];
        long pageCount = 0;
        while([countSet next]) {
            pageCount = [countSet longForColumn:@"page_count"];
        }
        [countSet close];
        fileSize = pageCount * pageSize;
    }];
    return fileSize;
}
- (BOOL)zy_isExistTable:(NSString *)tableName{
    __block NSInteger count = 0;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        ZY_FMResultSet *set = [db executeQuery:@"SELECT count(*) as 'count' FROM sqlite_master "
                               "WHERE type ='table' and name = ?", tableName];
        while([set next]) {
            count = [set intForColumn:@"count"];
        }
        [set close];
    }];
    
    return count > 0;
}
- (void)zy_inDatabase:(void (^)(ZY_FMDatabase *db))block{
    [[self dbQueue] inDatabase:^(ZY_FMDatabase *db) {
        block(db);
    }];
}
- (BOOL)vacuumDB{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        is = [db executeUpdate:@"vacuum;"];
    }];
    return is;
}
- (BOOL)autoVacuum{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        is = [db executeUpdate:@"PRAGMA auto_vacuum = INCREMENTAL"];
        if(is){
            FTInnerLogDebug(@"PRAGMA auto_vacuum = INCREMENTAL Success");
        }
    }];
    return is;
}
-(void)setEnableLimitWithDbSize:(BOOL)enableLimitWithDbSize{
    _enableLimitWithDbSize = enableLimitWithDbSize;
    if(enableLimitWithDbSize){
        [self autoVacuum];
    }
}
- (void)shutDown{
    [self close];
    onceToken = 0;
    dbTool = nil;
}
-(void)dealloc{
    [self close];
}
@end
