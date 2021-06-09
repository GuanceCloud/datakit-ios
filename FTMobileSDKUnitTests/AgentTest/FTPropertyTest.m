//
//  FTPropertyTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/18.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>
#import <FTLocationManager.h>
#import <Network/FTUploadTool.h>
#import "FTUploadTool+Test.h"
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTMobileAgent/Network/NSURLRequest+FTMonitor.h>
#import <objc/runtime.h>
#import <FTJSONUtil.h>
#import "NSString+FTAdd.h"
#import <FTMobileAgent/FTPresetProperty.h>
@interface FTPropertyTest : XCTestCase
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTPropertyTest

- (void)setUp {
    /**
     * 设置 ft-sdk-iosTestUnitTests 的 Environment Variables
     * 额外 添加 isUnitTests = 1 防止 SDK 在 AppDelegate 启动 对单元测试造成影响
     */
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

-(void)testSetEmptyServiceName{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:1];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[@"tags"];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue(serviceName.length>0);
    [[FTMobileAgent sharedInstance] resetInstance];
}

-(void)testSetServiceName{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.serviceName = @"testSetServiceName";
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[@"tags"];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([serviceName isEqualToString:@"testSetServiceName"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * source
 */
- (void)testSetEmptySource{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptySource" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *body = [request ft_getBodyData:YES];
    NSArray *bodyArray = [body componentsSeparatedByString:@","];
    XCTAssertTrue([[bodyArray firstObject] isEqualToString:@"ft_mobile_sdk_ios"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetSource{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.source = @"iOSTest";
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    [[FTMobileAgent sharedInstance] logging:@"testSetSource" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSURLRequest *request =  [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        
    }];
    NSString *body = [request ft_getBodyData:YES];
    NSArray *bodyArray = [body componentsSeparatedByString:@","];
    XCTAssertTrue([[bodyArray firstObject] isEqualToString:@"iOSTest"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetEmptyEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.source = @"iOSTest";
    [FTMobileAgent startWithConfigOptions:config];
    NSDictionary *dict = [[FTMobileAgent sharedInstance].presetProperty esPropertyWithType:@"view" terminal:@"app"];
    NSString *env = dict[@"env"];
    XCTAssertTrue([env isEqualToString:@"prod"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testSetEnv{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.source = @"iOSTest\\";
    config.env = FTEnvPre;
    [FTMobileAgent startWithConfigOptions:config];
    NSDictionary *dict = [[FTMobileAgent sharedInstance].presetProperty esPropertyWithType:@"view" terminal:@"app"];
    NSString *env = dict[@"env"];
    XCTAssertTrue([env isEqualToString:@"pre"]);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * url 为 空字符串
 * 验证标准：url为空字符串时 FTMobileAgent 调用  - startWithConfigOptions： 会崩溃 为 true
 */
- (void)testSetEmptyUrl{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@""];
    
    XCTAssertThrows([FTMobileAgent startWithConfigOptions:config]);
}
- (void)testIllegalUrl{
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:[NSString stringWithFormat:@"%@11",self.url]];
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logging:@"testIllegalUrl" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getAllDatas] lastObject];
    [[FTMobileAgent sharedInstance].upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
        [expect fulfill];
    }];
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
@end
