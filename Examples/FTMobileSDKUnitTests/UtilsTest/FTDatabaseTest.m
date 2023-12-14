//
//  FTDatabaseTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTTrackerEventDBTool.h"
#import "FTTrackerEventDBTool+Test.h"
#import "ZY_FMDatabase.h"
#import "FTRecordModel.h"
#import "FTDateUtil.h"
#import "FTTrackDataManager.h"
#import "FTModelHelper.h"
#import "FTConstants.h"
@interface FTDatabaseTest : XCTestCase
@property (nonatomic, copy) NSString *dbName;
@end

@implementation FTDatabaseTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] resetInstance];
    self.dbName = [NSString stringWithFormat:@"%@test.sqlite",[NSUUID UUID].UUIDString];
    [FTTrackerEventDBTool shareDatabaseWithPath:nil dbName:self.dbName];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [FTTrackerEventDBTool sharedManger].dbLoggingMaxCount = 5000;
}

- (void)tearDown {
    [[FTTrackerEventDBTool sharedManger] resetInstance];
    NSString  *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:self.name];
    NSError *errpr;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&errpr];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testCreateDB{
    ZY_FMDatabase *dataBase = [FTTrackerEventDBTool sharedManger].db;
    NSString *path =  dataBase.databasePath;
    XCTAssertTrue([path containsString:self.dbName]);
}
-(void)testCreateTable{
    BOOL  track = [[FTTrackerEventDBTool sharedManger] zy_isExistTable:FT_DB_TRACE_EVENT_TABLE_NAME];
    XCTAssertTrue(track);
}
- (void)testInsertSingle{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTRecordModel *model = [FTRecordModel new];
    model.op = @"test";
    model.data = @"testData";
    [[FTTrackerEventDBTool sharedManger] insertItem:model];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 1);
    
}
- (void)testGetDatasCount{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 15);
}
- (void)testInsertItemsWithDatas{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSMutableArray *array = [NSMutableArray new];
    for (int i = 0; i<10; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [array addObject:model];
    }
    [[FTTrackerEventDBTool sharedManger] insertItemsWithDatas:array];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 10);
}
- (void)testInsertLoggingItems{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    for (int i = 0; i<20; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackerEventDBTool sharedManger] insertLoggingItems:model];
    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 20);
    
}
/**
*  @abstract
*  缓存中的数据添加到数据库中
*/
-(void)testInsertCacheToDB{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel];
        [[FTTrackerEventDBTool sharedManger] insertLoggingItems:model];
    }
    [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 15);
}

-(void)testGetAllDatas{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
   NSArray *datas = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(datas.count == 15);

}
-(void)testGetFirstRecords{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
   NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(datas.count == 1);
}

-(void)testDeleteItemWithType{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
    [[FTTrackerEventDBTool sharedManger] deleteItemWithType:FT_DATA_TYPE_LOGGING tm:[FTDateUtil currentTimeNanosecond]];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 0);
}

-(void)testDeleteLoggingItem{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];

    [[FTTrackerEventDBTool sharedManger] deleteLoggingItem:5];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];

    XCTAssertTrue(oldCount - newCount == 5);
}
- (void)testGetDatasCountWithOp{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(count == 15);
}
- (void)testDelete{
    FTRecordModel *model = [FTRecordModel new];
    model.op = @"test";
    model.data = @"testData";
    [[FTTrackerEventDBTool sharedManger] insertItem:model];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(oldCount>0 && newCount == 0);
}


@end
