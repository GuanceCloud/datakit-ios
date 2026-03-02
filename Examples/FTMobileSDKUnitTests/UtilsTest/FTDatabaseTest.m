//
//  FTDatabaseTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by hulilei on 2020/8/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTTrackerEventDBTool.h"
#import "FTTrackerEventDBTool+Test.h"
#import "ZY_FMDatabase.h"
#import "FTRecordModel.h"
#import "NSDate+FTUtil.h"
#import "FTTrackDataManager.h"
#import "FTModelHelper.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTLog+Private.h"
@interface FTDatabaseTest : XCTestCase
@property (nonatomic, copy) NSString *dbName;
@end

@implementation FTDatabaseTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [FTLog enableLog:YES];

    [[FTTrackerEventDBTool sharedManager] shutDown];
    self.dbName = [NSString stringWithFormat:@"%@test.sqlite",[FTBaseInfoHandler randomUUID]];
    [FTTrackerEventDBTool shareDatabaseWithPath:nil dbName:self.dbName];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
}

- (void)tearDown {
    NSString *path = [FTTrackerEventDBTool sharedManager].dbQueue.path;
    [[FTTrackerEventDBTool sharedManager] shutDown];
    NSError *errpr;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&errpr];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testCreateDB{
    ZY_FMDatabaseQueue *dbQueue = [FTTrackerEventDBTool sharedManager].dbQueue;
    NSString *path =  dbQueue.path;
    XCTAssertTrue([path containsString:self.dbName]);
}
-(void)testCreateTable{
    BOOL  track = [[FTTrackerEventDBTool sharedManager] zy_isExistTable:FT_DB_TRACE_EVENT_TABLE_NAME];
    XCTAssertTrue(track);
}
- (void)testInsertSingle{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    FTRecordModel *model = [FTRecordModel new];
    model.op = @"test";
    model.data = @"testData";
    [[FTTrackerEventDBTool sharedManager] insertItem:model];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 1);
    
}
- (void)testGetDatasCount{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:model];
    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount == 15);
}
- (void)testInsertItemsWithDatas{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    NSMutableArray *array = [NSMutableArray new];
    for (int i = 0; i<10; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [array addObject:model];
    }
    [[FTTrackerEventDBTool sharedManager] insertItemsWithDatas:array];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 10);
}
- (void)testInsertLoggingItems{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    for (int i = 0; i<20; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];
    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 20);
}
/**
*  @abstract
*  Add data from cache to database
*/
-(void)testInsertCacheToDB{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];
    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 15);
}
                     
-(void)testGetAllDatas{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:model];
    }
   NSArray *datas = [[FTTrackerEventDBTool sharedManager] getAllDatas];
    XCTAssertTrue(datas.count == 15);

}
-(void)testGetFirstRecords{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:model];
    }
   NSArray *datas = [[FTTrackerEventDBTool sharedManager] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(datas.count == 1);
}

-(void)testDeleteItemWithType{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        FTRecordModel *rumModel = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:rumModel];
        [[FTTrackerEventDBTool sharedManager] insertItem:model];
    }
    [[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_LOGGING count:15];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount == 15);
}
- (void)testDeleteDataWithCount{
    for (int i = 0; i<50; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        FTRecordModel *rumModel = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:rumModel];
        [[FTTrackerEventDBTool sharedManager] insertItem:model];
    }
    [[FTTrackerEventDBTool sharedManager] deleteDataWithCount:50];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(newCount == 50);
}
-(void)testDeleteLoggingItem{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:model];
    }
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];

    [[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_LOGGING count:5];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];

    XCTAssertTrue(oldCount - newCount == 5);
}
- (void)testGetDatasCountWithOp{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:model];
    }
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(count == 15);
}
- (void)testDelete{
    FTRecordModel *model = [FTRecordModel new];
    model.op = @"test";
    model.data = @"testData";
    [[FTTrackerEventDBTool sharedManager] insertItem:model];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(oldCount>0 && newCount == 0);
}

- (void)testEnableLimitDBSize_deleteData{
    [[FTTrackerEventDBTool sharedManager] setEnableLimitWithDbSize:YES];
    for (int i = 0; i<100; i++) {
        FTRecordModel *logModel = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        FTRecordModel *rumModel = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManager] insertItem:logModel];
        [[FTTrackerEventDBTool sharedManager] insertItem:rumModel];
    }
    NSInteger count = [[FTTrackerEventDBTool sharedManager] getDatasCount];
    XCTAssertTrue(count == 200);
    long size = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    XCTAssertTrue(size>0);
    [[FTTrackerEventDBTool sharedManager] deleteDataWithCount:50];
    long dSize1 = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    
    [[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_LOGGING count:20];
    long dSize2 = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    [[FTTrackerEventDBTool sharedManager] deleteDataWithType:FT_DATA_TYPE_RUM count:20];
    long dSize3 = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];

    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManager] getFirstRecords:100 withType:FT_DATA_TYPE_LOGGING] lastObject];

    [[FTTrackerEventDBTool sharedManager] deleteItemWithType:FT_DATA_TYPE_LOGGING identify:model._id count:100];
    long dSize4 = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];

    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManager] getDatasCount] == 0);
    long dSize = [[FTTrackerEventDBTool sharedManager] checkDatabaseSize];
    XCTAssertTrue(dSize < dSize4 && dSize4 < dSize3 && dSize3 < dSize2 && dSize2 < dSize1);
}
@end
