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

    [[FTTrackerEventDBTool sharedManger] shutDown];
    self.dbName = [NSString stringWithFormat:@"%@test.sqlite",[FTBaseInfoHandler randomUUID]];
    [FTTrackerEventDBTool shareDatabaseWithPath:nil dbName:self.dbName];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}

- (void)tearDown {
    NSString *path = [FTTrackerEventDBTool sharedManger].dbQueue.path;
    [[FTTrackerEventDBTool sharedManger] shutDown];
    NSError *errpr;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&errpr];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testCreateDB{
    ZY_FMDatabaseQueue *dbQueue = [FTTrackerEventDBTool sharedManger].dbQueue;
    NSString *path =  dbQueue.path;
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
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    for (int i = 0; i<20; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];
    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 20);
}
/**
*  @abstract
*  缓存中的数据添加到数据库中
*/
-(void)testInsertCacheToDB{
    [FTTrackDataManager startWithAutoSync:NO syncPageSize:10 syncSleepTime:0];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];
    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
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
        FTRecordModel *rumModel = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:rumModel];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
    [[FTTrackerEventDBTool sharedManger] deleteDataWithType:FT_DATA_TYPE_LOGGING count:15];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 15);
}
- (void)testDeleteDataWithCount{
    for (int i = 0; i<50; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        FTRecordModel *rumModel = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:rumModel];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
    [[FTTrackerEventDBTool sharedManger] deleteDataWithCount:50];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 50);
}
-(void)testDeleteLoggingItem{
    for (int i = 0; i<15; i++) {
        FTRecordModel *model = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:model];
    }
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];

    [[FTTrackerEventDBTool sharedManger] deleteDataWithType:FT_DATA_TYPE_LOGGING count:5];
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
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(oldCount>0 && newCount == 0);
}

- (void)testEnableLimitDBSize_deleteData{
    [[FTTrackerEventDBTool sharedManger] setEnableLimitWithDbSize:YES];
    for (int i = 0; i<100; i++) {
        FTRecordModel *logModel = [FTModelHelper createLogModel:[NSString stringWithFormat:@"testData%d",i]];
        FTRecordModel *rumModel = [FTModelHelper createRUMModel:[NSString stringWithFormat:@"testData%d",i]];
        [[FTTrackerEventDBTool sharedManger] insertItem:logModel];
        [[FTTrackerEventDBTool sharedManger] insertItem:rumModel];
    }
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(count == 200);
    long size = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    XCTAssertTrue(size>0);
    [[FTTrackerEventDBTool sharedManger] deleteDataWithCount:50];
    long dSize1 = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    
    [[FTTrackerEventDBTool sharedManger] deleteDataWithType:FT_DATA_TYPE_LOGGING count:10];
    long dSize2 = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    [[FTTrackerEventDBTool sharedManger] deleteDataWithType:FT_DATA_TYPE_RUM count:10];
    long dSize3 = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];

    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];

    [[FTTrackerEventDBTool sharedManger] deleteItemWithType:FT_DATA_TYPE_LOGGING identify:model._id count:1];
    long dSize4 = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];

    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    XCTAssertTrue([[FTTrackerEventDBTool sharedManger] getDatasCount] == 0);
    long dSize = [[FTTrackerEventDBTool sharedManger] checkDatabaseSize];
    XCTAssertTrue(dSize < dSize4 < dSize3 < dSize2 < dSize1);
}
@end
