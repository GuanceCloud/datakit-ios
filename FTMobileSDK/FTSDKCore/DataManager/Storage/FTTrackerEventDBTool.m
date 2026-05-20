//
//  ZYSQLite3.m
//  FTMobileAgent
//
//  Created by hulilei on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTTrackerEventDBTool.h"
#import "ZY_FMDB.h"
#import "FTRecordModel.h"
#import "FTInnerLog.h"
#import "FTConstants.h"
#import "FTSDKCompat.h"
static NSString * const FT_DB_REMOTE_FILTER_CHECKED = @"remote_filter_checked";
@interface FTTrackerEventDBTool ()
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) ZY_FMDatabaseQueue *dbQueue;
@property (nonatomic, assign) BOOL enableLimitWithDbSize;

@end
@implementation FTTrackerEventDBTool
static FTTrackerEventDBTool *dbTool = nil;
static dispatch_once_t onceToken;
#pragma mark --Create database
+ (instancetype)sharedManager
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
        return nil;
    };
    return dbTool;
}
- (id)copyWithZone:(struct _NSZone *)zone {
    return self;
}
- (id)mutableCopyWithZone:(struct _NSZone *)zone {
    return self;
}
- (void)createTable{
    @try {
        [self createEventTable];
        [self enableWAL];
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@",exception);
    }
}
-(void)createEventTable{
    if ([self zy_isExistTable:FT_DB_TRACE_EVENT_TABLE_NAME]) {
        [self migrateEventTableIfNeeded];
        return;
    }
    [[self dbQueue] inTransaction:^(ZY_FMDatabase *db, BOOL *rollback) {
        NSDictionary *keyTypes = @{@"_id":@"INTEGER",
                                   @"tm":@"INTEGER",
                                   @"data":@"TEXT",
                                   @"op":@"TEXT",
                                   FT_DB_REMOTE_FILTER_CHECKED:@"INTEGER DEFAULT 0",
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
- (void)migrateEventTableIfNeeded{
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        if (![self table:FT_DB_TRACE_EVENT_TABLE_NAME hasColumn:FT_DB_REMOTE_FILTER_CHECKED database:db]) {
            NSString *sqlStr = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ INTEGER DEFAULT 0",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_REMOTE_FILTER_CHECKED];
            BOOL success = [db executeUpdate:sqlStr];
            FTInnerLogDebug(@"migrate %@ column %@ success == %d",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_REMOTE_FILTER_CHECKED,success);
        }
    }];
}
- (BOOL)table:(NSString *)tableName hasColumn:(NSString *)columnName database:(ZY_FMDatabase *)db{
    NSString *sqlStr = [NSString stringWithFormat:@"PRAGMA table_info(%@)",tableName];
    ZY_FMResultSet *set = [db executeQuery:sqlStr];
    BOOL hasColumn = NO;
    while ([set next]) {
        NSString *name = [set stringForColumn:@"name"];
        if ([name isEqualToString:columnName]) {
            hasColumn = YES;
            break;
        }
    }
    [set close];
    return hasColumn;
}
-(void)enableWAL{
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        [db executeQuery:@"PRAGMA journal_mode=WAL;"];
    }];
}
-(BOOL)insertItem:(FTRecordModel *)item{
    __block BOOL success = NO;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO %@ ( tm , data , op , %@) VALUES (  ? , ? , ? , ? );",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_REMOTE_FILTER_CHECKED];
        success=  [db executeUpdate:sqlStr,@(item.tm),item.data,item.op,@(item.remoteFilterChecked)];
    }];
    return success;
}
-(BOOL)insertItemsWithDatas:(NSArray<FTRecordModel*> *)items{
    if(items.count>0){
        __block BOOL needRollback = NO;
        [[self dbQueue] inTransaction:^(ZY_FMDatabase *db, BOOL *rollback) {
            [items enumerateObjectsUsingBlock:^(FTRecordModel *item, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO %@ ( tm , data , op , %@) VALUES (  ? , ? , ? , ? );",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_REMOTE_FILTER_CHECKED];
                if(![db executeUpdate:sqlStr,@(item.tm),item.data,item.op,@(item.remoteFilterChecked)]){
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
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY tm ASC  ;",FT_DB_TRACE_EVENT_TABLE_NAME];
    return [self getDatasWithFormat:sql arguments:nil];
}

-(NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type{
    if (recordSize == 0) {
        return @[];
    }
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE op = ? ORDER BY _id ASC limit ? ;",FT_DB_TRACE_EVENT_TABLE_NAME];
    
    return [self getDatasWithFormat:sql arguments:@[type,@(recordSize)]];
}

-(NSArray *)getDatasWithFormat:(NSString *)format arguments:(NSArray *)arguments{
    __block  NSMutableArray *array = [NSMutableArray new];
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        //ORDER BY ID DESC --Find by ID in descending order: ORDER BY ID ASC --Find by ID in ascending order
        ZY_FMResultSet *set = nil;
        if (arguments && arguments.count > 0) {
            set = [db executeQuery:format withArgumentsInArray:arguments];
        } else {
            set = [db executeQuery:format];
        }
        if (!set) return;
        while(set.next) {
            //Create object and assign values
            FTRecordModel* item = [[FTRecordModel alloc]init];
            item.tm = [set longForColumn:@"tm"];
            item.data= [set stringForColumn:@"data"];
            item.op = [set stringForColumn:@"op"];
            item._id = [NSString stringWithFormat:@"%ld",[set longForColumn:@"_id"]];
            int remoteFilterCheckedColumn = [set columnIndexForName:FT_DB_REMOTE_FILTER_CHECKED];
            item.remoteFilterChecked = remoteFilterCheckedColumn >= 0 ? [set boolForColumnIndex:remoteFilterCheckedColumn] : NO;
            [array addObject:item];
        }
        [set close];
    }];
    return [array copy];
}
- (NSInteger)getDatasCount{
    __block NSInteger count =0;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", FT_DB_TRACE_EVENT_TABLE_NAME];
        ZY_FMResultSet *set = [db executeQuery:sqlStr];
        while ([set next]) {
            count= [set intForColumn:@"count"];
        }
        [set close];
    }];
    return count;
}
- (NSInteger)getUploadDatasCount{
    __block NSInteger count =0;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@ WHERE op = ? or op = ?", FT_DB_TRACE_EVENT_TABLE_NAME];
        ZY_FMResultSet *set = [db executeQuery:sqlStr,FT_DATA_TYPE_LOGGING,FT_DATA_TYPE_RUM];
        while ([set next]) {
            count= [set intForColumn:@"count"];
        }
        [set close];
    }];
    return count;
}
- (NSInteger)getDatasCountWithType:(NSString *)op{
    __block NSInteger count =0;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@ WHERE op = ?", FT_DB_TRACE_EVENT_TABLE_NAME];
        ZY_FMResultSet *set = [db executeQuery:sqlStr,op];
        while ([set next]) {
            count= [set intForColumn:@"count"];
        }
        [set close];
    }];
    return count;
}
-(BOOL)deleteItemWithType:(NSString *)type identify:(NSString *)identify count:(NSInteger)count{
    __block BOOL is;
    __weak __typeof(self) weakSelf = self;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE op = ? AND _id <= ? ;",FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,type,identify];
        if(weakSelf.enableLimitWithDbSize){
            NSString *str = [NSString stringWithFormat:@"PRAGMA incremental_vacuum(%ld)", (long)count];
            ZY_FMResultSet *set = [db executeQuery:str];
            [set close];
        }
    }];
    return is;
}
-(BOOL)deleteDataWithType:(NSString *)type count:(NSInteger)count{
    __block BOOL is;
    __weak __typeof(self) weakSelf = self;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE _id in (SELECT _id from '%@' WHERE  op = ? ORDER by _id ASC LIMIT ? )",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,type,@(count)];
        if(weakSelf.enableLimitWithDbSize){
            NSString *str = [NSString stringWithFormat:@"PRAGMA incremental_vacuum(%ld)", (long)count];
            ZY_FMResultSet *set = [db executeQuery:str];
            [set close];
        }
    }];
    return is;
}
-(BOOL)deleteDataWithCount:(NSInteger)count{
    __block BOOL is;
    __weak __typeof(self) weakSelf = self;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE _id in (SELECT _id from '%@' ORDER by _id ASC LIMIT ?)",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,@(count)];
        if(weakSelf.enableLimitWithDbSize){
            NSString *str = [NSString stringWithFormat:@"PRAGMA incremental_vacuum(%ld)", (long)count];
            ZY_FMResultSet *set = [db executeQuery:str];
            [set close];
        }
    }];
    return is;
}
-(BOOL)deleteAllDatas{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM %@;",FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr];
    }];
    return is;
}
- (BOOL)deleteDatasWithType:(NSString *)type{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE  op = ? ",FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,type];
    }];
    return is;
}
- (BOOL)deleteDatasWithType:(NSString *)type toTime:(long long)toTime{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE _id in (SELECT _id from '%@' WHERE  op = ? AND tm < ? )",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,type,@(toTime)];
    }];
    return is;
}
- (BOOL)deleteDatasWithType:(NSString *)type fromTime:(long long)fromTime toTime:(long long)toTime{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE _id in (SELECT _id from '%@' WHERE  op = ? AND tm >= ? AND tm <= ? )",FT_DB_TRACE_EVENT_TABLE_NAME,FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,type,@(fromTime),@(toTime)];
    }];
    return is;
}
- (BOOL)updateDatasWithType:(NSString *)type toType:(NSString *)toType toTime:(long long)toTime{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"UPDATE %@ SET op = ?  WHERE  tm <= ?  AND op = ?",FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,toType,@(toTime),type];
    }];
    return is;
}
- (BOOL)updateDatasWithType:(NSString *)type toType:(NSString *)toType fromTime:(long long)fromTime toTime:(long long)toTime{
    __block BOOL is;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        NSString *sqlStr = [NSString stringWithFormat:@"UPDATE %@ SET op = ?  WHERE tm >= ? AND tm <= ?  AND op = ?",FT_DB_TRACE_EVENT_TABLE_NAME];
        is = [db executeUpdate:sqlStr,toType,@(fromTime),@(toTime),type];
    }];
    return is;
}
- (void)close{
    [self vacuumDB];
    [[self dbQueue] close];
}
static long pageSize = 0;
- (long long)checkDatabaseSize {
    __block long long actualUsedSize = -1;
    [self zy_inDatabase:^(ZY_FMDatabase *db){
        if (pageSize <= 0) {
            ZY_FMResultSet *pageSizeSet = [db executeQuery:@"PRAGMA page_size;"];
            if ([pageSizeSet next]) {
                pageSize = [pageSizeSet longForColumn:@"page_size"];
            }
            [pageSizeSet close];
            
            if (pageSize <= 0) {
                FTInnerLogError(@"get page_size fail，default set 4096");
                pageSize = 4096;
            }
        }
        
        long totalPageCount = 0;
        ZY_FMResultSet *pageCountSet = [db executeQuery:@"PRAGMA page_count;"];
        if ([pageCountSet next]) {
            totalPageCount = [pageCountSet longForColumn:@"page_count"];
        }
        [pageCountSet close];
        
        long freePageCount = 0;
        ZY_FMResultSet *freePageSet = [db executeQuery:@"PRAGMA freelist_count;"];
        if ([freePageSet next]) {
            freePageCount = [freePageSet longForColumn:@"freelist_count"];
        }
        [freePageSet close];
        
        long usedPageCount = totalPageCount - freePageCount;
        actualUsedSize = (long long)usedPageCount * pageSize;
    }];
    return actualUsedSize;
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
/**
 * Only used for testing.
 */
- (void)shutDown{
    [self close];
    onceToken = 0;
    dbTool = nil;
}
@end
