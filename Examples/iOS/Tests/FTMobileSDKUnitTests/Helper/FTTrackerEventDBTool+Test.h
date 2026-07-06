//
//  FTTrackerEventDBTool+Test.h
//  ft-sdk-iosTestUnitTests
//
//  Created by hulilei on 2020/8/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTTrackerEventDBTool.h"
#import "ZY_FMDB.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTTrackerEventDBTool (Test)
@property (nonatomic, strong) ZY_FMDatabaseQueue *dbQueue;
@property (nonatomic, assign) BOOL incrementalAutoVacuumEnabled;
+ (nullable FTTrackerEventDBTool *)shareDatabaseWithPath:(nullable NSString *)dbPath dbName:(nullable NSString *)dbName enableLimitWithDbSize:(BOOL)enableLimitWithDbSize;
- (BOOL)zy_isExistTable:(NSString *)tableName;
- (long)checkDatabaseSize;
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
