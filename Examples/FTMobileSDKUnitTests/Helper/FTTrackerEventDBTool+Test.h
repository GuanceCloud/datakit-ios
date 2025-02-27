//
//  FTTrackerEventDBTool+Test.h
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTTrackerEventDBTool.h"
#import "ZY_FMDB.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTTrackerEventDBTool (Test)
@property (nonatomic, strong) ZY_FMDatabaseQueue *dbQueue;
- (BOOL)zy_isExistTable:(NSString *)tableName;
- (long)checkDatabaseSize;
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
