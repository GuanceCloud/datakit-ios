//
//  FTDatabaseTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import "FTTrackerEventDBTool+Test.h"
#import <FTDataBase/fmdb/ZY_FMDatabase.h>
#import <FTRecordModel.h>
#import <FTMobileAgent/NSDate+FTAdd.h>

@interface FTDatabaseTest : XCTestCase

@end

@implementation FTDatabaseTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] resetInstance];
    [FTTrackerEventDBTool shareDatabase:@"test.sqlite"];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}

- (void)tearDown {
    [[FTTrackerEventDBTool sharedManger] resetInstance];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testCreateDB{
    ZY_FMDatabase *dataBase = [FTTrackerEventDBTool sharedManger].db;
    NSString *path =  dataBase.databasePath;
    XCTAssertTrue([path containsString:@"test.sqlite"]);
}
-(void)testCreateTable{
    BOOL  track = [[FTTrackerEventDBTool sharedManger] zy_isExistTable:FT_DB_TRACREVENT_TABLE_NAME];
    BOOL  user = [[FTTrackerEventDBTool sharedManger] zy_isExistTable:FT_DB_USERSESSION_TABLE_NAME];
    XCTAssertTrue(track && user);
}
- (void)testInsertSingle{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTRecordModel *model = [FTRecordModel new];
    model.op = @"test";
    model.data = @"testData";
    [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 1);
    
}
- (void)testInsertBulk{
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    NSMutableArray *array = [NSMutableArray new];
    for (int i = 0; i<30; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [array addObject:model];
    }
    [[FTTrackerEventDBTool sharedManger] insertItemWithItemDatas:array];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-oldCount == 30);
    
}
- (void)testDelete{
    FTRecordModel *model = [FTRecordModel new];
    model.op = @"test";
    model.data = @"testData";
    [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(oldCount>0 && newCount == 0);
}

- (void)testDiscardSingle{
    for (int i = 0; i<5005; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 5000);
}
- (void)testDiscardBulk{
    NSMutableArray *array = [NSMutableArray new];
    for (int i = 0; i<5005; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [array addObject:model];
    }
    [[FTTrackerEventDBTool sharedManger] insertItemWithItemDatas:array];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 5000);
}

- (void)testCache{
    for (int i = 0; i<101; i++) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FTRecordModel *model = [FTRecordModel new];
        model.op = [NSString stringWithFormat:@"test%d",i];
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackerEventDBTool sharedManger] insertItemToCache:model];
    });
    }
    [NSThread sleepForTimeInterval:2];
    [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 101);
}
@end
