//
//  ZYSQLite3.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTTrackerEventDBTool.h"
#import "FTRecordModel.h"
#import "ZY_FMDB.h"
#import "FTLog.h"
@interface FTTrackerEventDBTool ()
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) ZY_FMDatabaseQueue *dbQueue;
@property (nonatomic, strong) ZY_FMDatabase *db;

@property (nonatomic, strong) NSDate *lastSentDate;

@end
@implementation FTTrackerEventDBTool
static FTTrackerEventDBTool *dbTool = nil;

#pragma mark --创建数据库
+ (instancetype)sharedManger {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    if (!dbTool) {
        NSString  *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZYFMDB.sqlite"];
        ZY_FMDatabaseQueue *dbQueue = [ZY_FMDatabaseQueue databaseQueueWithPath:path];
        ZY_FMDatabase *fmdb = [dbQueue valueForKey:@"_db"];
        if ([fmdb  open]) {
            dbTool = FTTrackerEventDBTool.new;
            dbTool.db = fmdb;
            dbTool.dbPath = path;
            ZYDebug(@"db path:%@",path);
            dbTool.dbQueue = dbQueue;
        }
        [dbTool createTable];
     }
    });
    if (![dbTool.db open]) {
        ZYDebug(@"database can not open !");
        return nil;
    };
    return dbTool;
}
- (void)createTable{
    @try {
        [self createEventTable];
        [self createUserTable];
    } @catch (NSException *exception) {
        ZYDebug(@"%@",exception);
    }
}
-(void)createEventTable
{
    if ([self zy_isExistTable:FT_DB_TRACREVENT_TABLE_NAME]) {
        return;
    }
      [self zy_inTransaction:^(BOOL *rollback) {
        NSDictionary *keyTypes = @{@"_id":@"INTEGER",
                                   @"tm":@"INTEGER",
                                   @"data":@"TEXT",
                                   @"sessionid":@"TEXT",
                                   @"op":@"TEXT",
        };
        if ([self isOpenDatabese:self.db]) {
               NSMutableString *sql = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (",FT_DB_TRACREVENT_TABLE_NAME]];
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
- (void)createUserTable{
    if ([self zy_isExistTable:FT_DB_USERSESSION_TABLE_NAME]) {
           return;
       }
    [self zy_inTransaction:^(BOOL *rollback) {
           NSDictionary *keyTypes = @{@"usersessionid":@"TEXT",
                                      @"userdata":@"TEXT",
           };
           if ([self isOpenDatabese:self.db]) {
                  NSMutableString *sql = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (",FT_DB_USERSESSION_TABLE_NAME]];
                  int count = 0;//%@  INTEGER PRIMARY KEY
                  for (NSString *key in keyTypes) {
                      count++;
                      [sql appendString:key];
                      [sql appendString:@" "];
                      [sql appendString:[keyTypes valueForKey:key]];
                      if ([key isEqualToString:@"usersessionid"]) {
                           [sql appendString:@" PRIMARY KEY"];
                      }
                      if (count != [keyTypes count]) {
                           [sql appendString:@", "];
                      }
                  }
                  [sql appendString:@")"];
                  ZYDebug(@"%@", sql);
                BOOL success =[self.db executeUpdate:sql];
               ZYDebug(@"createUserTable success == %d",success);
              }
       }];
}
-(BOOL)insertUserDataWithName:(NSString *)name Id:(NSString *)Id exts:(NSDictionary *)exts{
    NSMutableDictionary *data = [@{@"name":name,
                           @"id":Id,
    } mutableCopy];
    if (exts) {
        [data addEntriesFromDictionary:@{@"exts":exts}];
    }
    
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:&parseError];
    
    NSString *userdata = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (!get_ft_sessionid) {
        NSString *sessionid = [[NSUUID UUID] UUIDString];
        set_ft_sessionid(sessionid);
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if([self isOpenDatabese:self.db]) {
        __block BOOL  is = NO;
        [self zy_inDatabase:^{
            NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'usersessionid' , 'userdata') VALUES ( ? , ? );",FT_DB_USERSESSION_TABLE_NAME];
           is=  [self.db executeUpdate:sqlStr,get_ft_sessionid,userdata];
            ZYDebug(@"bind user success == %ld \n userData = %@",is,userdata);
        }];
        return is;
    }else{
    return NO;
    }
}
-(void)delectLogoutUser{
    
}
-(BOOL)insertItemWithItemData:(FTRecordModel *)item{
    __block BOOL success = NO;
   if([self isOpenDatabese:self.db]) {
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data' , 'sessionid','op') VALUES (  ? , ? , ? , ? );",FT_DB_TRACREVENT_TABLE_NAME];
          success=  [self.db executeUpdate:sqlStr,@(item.tm),item.data,item.sessionid,item.op];
           ZYDebug(@"data storage success == %d",success);
       }];
   }
    if (self.lastSentDate) {
           NSDate* now = [NSDate date];
           NSTimeInterval time = [now timeIntervalSinceDate:self.lastSentDate];
           if (time>10) {
               self.lastSentDate = [NSDate date];
           //待处理通知
               [[NSNotificationCenter defaultCenter] postNotificationName:@"FTUploadNotification" object:nil];
           }
       }else{
           self.lastSentDate = [NSDate date];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FTUploadNotification" object:nil];
       }
    return success;
}

-(NSArray *)getAllDatas{
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' ORDER BY tm ASC  ;",FT_DB_TRACREVENT_TABLE_NAME];

    return [self getDatasWithFormat:sql bindUser:NO];

}
-(NSArray *)getFirstTenBindUserData:(NSString *)op{
    NSString *sessionidSql =[NSString stringWithFormat:@"SELECT * FROM '%@' join '%@' on %@.sessionid = %@.usersessionid WHERE %@.op = '%@' ORDER BY tm ASC limit 10 ;",FT_DB_TRACREVENT_TABLE_NAME,FT_DB_USERSESSION_TABLE_NAME,FT_DB_TRACREVENT_TABLE_NAME,FT_DB_USERSESSION_TABLE_NAME,FT_DB_TRACREVENT_TABLE_NAME,op];
    NSArray *session =[self getDatasWithFormat:sessionidSql bindUser:YES];

    return session;
   
}
-(NSArray *)getFirstTenData:(NSString *)op{
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' WHERE op = '%@' ORDER BY tm ASC limit 10  ;",FT_DB_TRACREVENT_TABLE_NAME,op];

    return [self getDatasWithFormat:sql bindUser:NO];
}
-(NSArray *)getBindUserDataWithOP:(NSString *)op{
    NSString *sessionidSql =[NSString stringWithFormat:@"SELECT * FROM '%@' join '%@' on %@.sessionid = %@.usersessionid WHERE %@.op = '%@' ORDER BY tm ASC limit 10 ;",FT_DB_TRACREVENT_TABLE_NAME,FT_DB_USERSESSION_TABLE_NAME,FT_DB_TRACREVENT_TABLE_NAME,FT_DB_USERSESSION_TABLE_NAME,FT_DB_TRACREVENT_TABLE_NAME,op];
    NSArray *session =[self getDatasWithFormat:sessionidSql bindUser:YES];
    
    return session;
}
-(NSArray *)getDatasWithOP:(NSString *)op{
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' WHERE op = '%@' ORDER BY tm ASC   ;",FT_DB_TRACREVENT_TABLE_NAME,op];
    
    return [self getDatasWithFormat:sql bindUser:NO];
}
-(NSArray *)getDatasWithFormat:(NSString *)format bindUser:(BOOL)bindUser{
    if([self isOpenDatabese:self.db]) {
        __block  NSMutableArray *array = [NSMutableArray new];
        [self zy_inDatabase:^{
            //ORDER BY ID DESC --根据ID降序查找:ORDER BY ID ASC --根据ID升序序查找
            ZY_FMResultSet*set = [self.db executeQuery:format];
            while(set.next) {
                //创建对象赋值
                FTRecordModel* item = [[FTRecordModel alloc]init];
                item._id= [[set stringForColumn:@"_id"]intValue];
                item.tm = [set longForColumn:@"tm"];
                item.data= [set stringForColumn:@"data"];
                item.op = [set stringForColumn:@"op"];
                if (bindUser) {
                    item.userdata = [set stringForColumn:@"userdata"];
                }
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
        NSString *sqlstr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", FT_DB_TRACREVENT_TABLE_NAME];
          ZY_FMResultSet *set = [self.db executeQuery:sqlstr];

          while ([set next]) {
              count= [set intForColumn:@"count"];
          }

    }];
     return count;
}
-(BOOL)deleteItemWithType:(NSString *)type tm:(long long)tm{
    __block BOOL is;
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE op = '%@' AND tm <= %lld ;",FT_DB_TRACREVENT_TABLE_NAME,type,tm];
           is = [self.db executeUpdate:sqlStr];
       }];
       return is;
}

-(BOOL)deleteItemWithTm:(long long)tm
{   __block BOOL is;
    [self zy_inDatabase:^{
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE tm <= %lld ;",FT_DB_TRACREVENT_TABLE_NAME,tm];
        is = [self.db executeUpdate:sqlStr];
    }];
    return is;
}
-(BOOL)deleteItemWithId:(long )Id
{   __block BOOL is;
    [self zy_inDatabase:^{
     NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE _id <= %ld ;",FT_DB_TRACREVENT_TABLE_NAME,Id];
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
