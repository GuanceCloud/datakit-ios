//
//  FTLoggerTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2021/6/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import <KIF/KIF.h>
#import "FTMobileAgent.h"
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent+Private.h"
#import "NSDate+FTUtil.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTRecordModel.h"
#import "UITestVC.h"
#import "FTTrackDataManager+Test.h"
#import "FTModelHelper.h"
@interface FTLoggerTest : KIFTestCase

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTLoggerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testEnableCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.printCustomLogToConsole = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount=count+1);
    [[FTMobileAgent sharedInstance] shutDown];

}
- (void)testDisbleCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = NO;
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [[FTLogger sharedInstance] info:@"testLoggingMethod" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count);
    [[FTMobileAgent sharedInstance] shutDown];

}
- (void)testDiscardNew{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscard;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<5030; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data isEqualToString:@"testData0"]);

    XCTAssertTrue(newCount == 5000);
    [[FTMobileAgent sharedInstance] shutDown];

}

- (void)testDiscardOldBulk{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscardOldest;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    for (int i = 0; i<5045; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 5000);
    [[FTMobileAgent sharedInstance] shutDown];

}
- (void)testLogLevelFilter{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusInfo)];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] info:@"testLoggingMethod" property:nil];
    
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount>count);
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethodError" status:FTStatusError];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger newCount2 =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount2 == newCount);
    [[FTMobileAgent sharedInstance] shutDown];


}
- (void)testEmptyStringMessageLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count);
    [[FTMobileAgent sharedInstance] shutDown];

}
- (void)testNotSetLoggerConfig{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] logging:@"testNotSetLoggerConfig" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] unbindUser];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[NSDate ft_currentNanosecondTimeStamp]];
}
-(void)testSetEmptyLoggerServiceName{
    [self setRightSDKConfig];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue(serviceName.length>0);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testEnableLinkRumData{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [FTModelHelper startView];
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];

    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags =opdata[FT_TAGS];
    XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
    XCTAssertTrue([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
    [[FTMobileAgent sharedInstance] shutDown];

}
- (void)testDisableLinkRumData{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = NO;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];

    [[FTMobileAgent sharedInstance] syncProcess];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags =opdata[FT_TAGS];
    XCTAssertFalse([tags.allKeys containsObject:FT_RUM_KEY_SESSION_ID]);
    XCTAssertFalse([tags.allKeys containsObject:FT_RUM_KEY_SESSION_TYPE]);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testSampleRate0{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.samplerate = 0;
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    [[FTMobileAgent sharedInstance] logging:@"testSampleRate0" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    XCTAssertTrue(oldDatas.count == newDatas.count);
    [[FTMobileAgent sharedInstance] shutDown];

}
- (void)testSampleRate100{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    [[FTMobileAgent sharedInstance] logging:@"testSampleRate0" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(oldDatas.count+1 == newDatas.count);
    [[FTMobileAgent sharedInstance] shutDown];

}
- (void)testGlobalContext{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.globalContext = @{@"logger_id":@"logger_id_1"};
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testGlobalContext" status:FTStatusInfo];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[FT_TAGS];
    XCTAssertTrue([tags[@"logger_id"] isEqualToString:@"logger_id_1"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testLoggerProperty{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLoggerProperty" status:FTStatusInfo property:@{@"logger_property":@"testLoggerProperty"}];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [newDatas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *fields = op[FT_FIELDS];
    XCTAssertTrue([fields[@"logger_property"] isEqualToString:@"testLoggerProperty"]);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testLoggerStatus{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTLogger sharedInstance] info:@"testInfo" property:nil];
    [[FTLogger sharedInstance] error:@"testError" property:nil];
    [[FTLogger sharedInstance] warning:@"testWarning" property:nil];
    [[FTLogger sharedInstance] critical:@"testCritical" property:nil];
    [[FTLogger sharedInstance] ok:@"testOk" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    NSInteger count = 0;
    NSDictionary *logStatus = @{@"testInfo":@"info",
                                @"testError":@"error",
                                @"testWarning":@"warning",
                                @"testCritical":@"critical",
                                @"testOk":@"ok"
    };
    for (FTRecordModel *model in newDatas) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
        NSDictionary *op = dict[@"opdata"];
        NSDictionary *tags = op[FT_TAGS];
        NSDictionary *fields = op[FT_FIELDS];
        NSString *message = fields[@"message"];
        NSString *status = tags[@"status"];
        if([logStatus.allKeys containsObject:message]){
            count ++;
            XCTAssertTrue([status isEqualToString:logStatus[message]]);
        }
    }
    XCTAssertTrue(count == 5);
    [[FTMobileAgent sharedInstance] shutDown];
}
- (void)testSDKShutDown{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSInteger oldCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTLogger sharedInstance] info:@"testLoggingMethod" property:nil];
    [[FTMobileAgent sharedInstance] syncProcess];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] shutDown];
    XCTAssertTrue(count>oldCount);
    [[FTLogger sharedInstance] error:@"testSDKShutDown" property:nil];
    [[FTLogger sharedInstance] warning:@"testSDKShutDown" property:nil];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertNoThrow([[FTLogger sharedInstance] ok:@"testSDKShutDown" property:nil]);
    XCTAssertTrue(count == newCount);
}
@end
