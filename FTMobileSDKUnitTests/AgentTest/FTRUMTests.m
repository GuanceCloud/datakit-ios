//
//  FTRUMTests.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/12/25.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTBaseInfoHander.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "FTUploadTool+Test.h"
#import "UITestVC.h"
#import <FTMobileAgent/NSDate+FTAdd.h>
#import "NSString+FTAdd.h"
#import <FTRecordModel.h>
#import <FTJSONUtil.h>

@interface FTRUMTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTRUMTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[UITestVC alloc] init];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.testVC];
    self.navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
/**
 * 设置 appid 后 ES 开启
 * 验证： ES 数据能正常写入
 */
- (void)testSetAppid{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.appid = self.appid;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSUInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount>count);
    [[FTMobileAgent sharedInstance] resetInstance];
}
/**
 * 未设置 appid  ES 关闭
 * 验证： ES 数据不能正常写入
 */
-(void)testSetEmptyAppid{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSUInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)addESData{
    NSDictionary *field = @{@"action_error_count":@0,
                            @"action_long_task_count":@0,
                            @"action_resource_count":@0,
                            @"duration":@103492975,
    };
    NSDictionary *tags = @{@"action_id":[NSUUID UUID].UUIDString,
                           @"action_name":@"app_cold_start",
                           @"action_type":@"launch_cold",
                           @"session_id":[NSUUID UUID].UUIDString,
                           @"session_type":@"user",
    };
    [[FTMobileAgent sharedInstance] rumWrite:@"action" terminal:@"app" tags:tags fields:field];
}
- (void)testViewDataFormatChecks{
    
    [self setESConfig];
    
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [NSThread sleepForTimeInterval:2];

        NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        __block BOOL hasView = NO;
        [array enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
            NSString *op = dict[@"op"];
            XCTAssertTrue([op isEqualToString:@"RUM"]);
            NSDictionary *opdata = dict[@"opdata"];
            NSString *measurement = opdata[@"measurement"];
            if ([measurement isEqualToString:@"view"]) {
                NSDictionary *tags = opdata[@"tags"];
                NSDictionary *field = opdata[@"field"];
                XCTAssertTrue([field.allKeys containsObject:@"view_resource_count"]&&[field.allKeys containsObject:@"view_action_count"]&&[field.allKeys containsObject:@"view_long_task_count"]&&[field.allKeys containsObject:@"view_error_count"]);
                XCTAssertTrue([tags.allKeys containsObject:@"is_active"]&&[tags.allKeys containsObject:@"view_id"]&&[tags.allKeys containsObject:@"view_referrer"]&&[tags.allKeys containsObject:@"view_name"]);
                hasView = YES;
                *stop = YES;
            }
        }];
        XCTAssertTrue(hasView);
        [[FTMobileAgent sharedInstance] resetInstance];
        [expectation fulfill];
    }];
   
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
  
}

- (void)testRumResourceData{
    [self setESConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [NSThread sleepForTimeInterval:3];
        if (!error) {
        NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        [array enumerateObjectsUsingBlock:^(FTRecordModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
            NSString *op = dict[@"op"];
            XCTAssertTrue([op isEqualToString:@"RUM"]);
            NSDictionary *opdata = dict[@"opdata"];
            NSString *measurement = opdata[@"measurement"];
            NSDictionary *tags = opdata[@"tags"];
            NSDictionary *field = opdata[@"field"];
            if([measurement isEqualToString:@"resource"]){
                [self rumTags:tags];
                XCTAssertTrue([tags.allKeys containsObject:@"resource_url"]&&[tags.allKeys containsObject:@"resource_url_host"]&&[tags.allKeys containsObject:@"resource_url_path"]&&[tags.allKeys containsObject:@"resource_type"]&&[tags.allKeys containsObject:@"response_server"]&&[tags.allKeys containsObject:@"response_content_type"]&&[tags.allKeys containsObject:@"resource_method"]&&[tags.allKeys containsObject:@"resource_status"]);
                XCTAssertTrue([field.allKeys containsObject:@"request_header"]&&[field.allKeys containsObject:@"response_header"]&&[field.allKeys containsObject:@"resource_size"]&&[field.allKeys containsObject:@"duration"]&&[field.allKeys containsObject:@"resource_dns"]&&[field.allKeys containsObject:@"resource_tcp"]&&[field.allKeys containsObject:@"resource_ssl"]&&[field.allKeys containsObject:@"resource_ttfb"]&&[field.allKeys containsObject:@"resource_trans"]);
            
        }
        }];
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testResourceDataFormatChecks{
    NSArray *resourceTag = @[@"resource_url",
                             @"resource_url_host",
    ];
    [self setESConfig];
    
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [NSThread sleepForTimeInterval:2];

        NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        __block BOOL hasView = NO;
        [array enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
            NSString *op = dict[@"op"];
            XCTAssertTrue([op isEqualToString:@"RUM"]);
            NSDictionary *opdata = dict[@"opdata"];
            NSString *measurement = opdata[@"measurement"];
            if ([measurement isEqualToString:@"resource"]) {
               
                hasView = YES;
                *stop = YES;
            }
        }];
        XCTAssertTrue(hasView);
        [[FTMobileAgent sharedInstance] resetInstance];
        [expectation fulfill];
    }];
   
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
  
}

- (void)testRumResourceData{
    [self setESConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [NSThread sleepForTimeInterval:3];
        if (!error) {
        NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        [array enumerateObjectsUsingBlock:^(FTRecordModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
            NSString *op = dict[@"op"];
            XCTAssertTrue([op isEqualToString:@"RUM"]);
            NSDictionary *opdata = dict[@"opdata"];
            NSString *measurement = opdata[@"measurement"];
            NSDictionary *tags = opdata[@"tags"];
            NSDictionary *field = opdata[@"field"];
            if([measurement isEqualToString:@"resource"]){
                [self rumTags:tags];
                XCTAssertTrue([tags.allKeys containsObject:@"resource_url"]&&[tags.allKeys containsObject:@"resource_url_host"]&&[tags.allKeys containsObject:@"resource_url_path"]&&[tags.allKeys containsObject:@"resource_type"]&&[tags.allKeys containsObject:@"response_server"]&&[tags.allKeys containsObject:@"response_content_type"]&&[tags.allKeys containsObject:@"resource_method"]&&[tags.allKeys containsObject:@"resource_status"]);
                XCTAssertTrue([field.allKeys containsObject:@"request_header"]&&[field.allKeys containsObject:@"response_header"]&&[field.allKeys containsObject:@"resource_size"]&&[field.allKeys containsObject:@"duration"]&&[field.allKeys containsObject:@"resource_dns"]&&[field.allKeys containsObject:@"resource_tcp"]&&[field.allKeys containsObject:@"resource_ssl"]&&[field.allKeys containsObject:@"resource_ttfb"]&&[field.allKeys containsObject:@"resource_trans"]);
            
        }
        }];
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)networkUploadHandler:(void (^)(NSURLResponse *response,NSError *error))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        completionHandler?completionHandler(response,error):nil;
    }];
    
    [task resume];
}
- (void)rumTags:(NSDictionary *)tags{
    NSArray *tagAry = @[@"sdk_name",
                        @"sdk_version",
                        @"app_id",
                        @"env",
                        @"version",
                        @"source",
                        @"userid",
                        @"session_id",
                        @"session_type",
                        @"is_signin",
                        @"device",
                        @"model",
                        @"device_uuid",
                        @"os",
                        @"os_version",
                        @"os_version_major",
                        @"screen_size",
    ];
    [tagAry enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        XCTAssertTrue([tags.allKeys containsObject:obj]);
    }];
}
- (void)setESConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableTraceUserAction = YES;
    config.appid = self.appid;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];

}
@end
