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
    NSString *name = @"TestBindUser";
    NSString *view_id = [name ft_md5HashToUpper32Bit];
    NSString *parent = FT_NULL_VALUE;
    NSDictionary *tags = @{@"view_id":view_id,
                           @"view_name":name,
                           @"view_parent":parent,
                           @"app_apdex_level":@0,
    };
    NSDictionary *fields = @{
        @"view_load":@100,
    }.mutableCopy;
    [[FTMobileAgent sharedInstance] rumTrackES:FT_TYPE_VIEW terminal:FT_TERMINAL_APP tags:tags fields:fields];
}

- (void)testViewData{
    
    [self setESConfig];
    
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [NSThread sleepForTimeInterval:3];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(array.count == 3);
  
    [array enumerateObjectsUsingBlock:^(FTRecordModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"measurement"];
        NSDictionary *tags = opdata[@"tags"];
        NSDictionary *field = opdata[@"field"];
        if ([measurement isEqualToString:@"rum_app_view"]) {
            [self rumInfluxDBtags:tags];
            XCTAssertTrue([field.allKeys containsObject:@"view_load"]);
            XCTAssertTrue([tags.allKeys containsObject:@"app_apdex_level"]&&[tags.allKeys containsObject:@"view_id"]&&[tags.allKeys containsObject:@"view_name"]&&[tags.allKeys containsObject:@"view_parent"]);
        }else if([measurement isEqualToString:@"view"]){
            [self rumEStags:tags];
            XCTAssertTrue([tags.allKeys containsObject:@"app_apdex_level"]&&[tags.allKeys containsObject:@"view_id"]&&[tags.allKeys containsObject:@"view_name"]&&[tags.allKeys containsObject:@"view_parent"]);
            XCTAssertTrue([field.allKeys containsObject:@"view_load"]);
        }else if([measurement isEqualToString:@"rum_app_startup"]){
            XCTAssertTrue([tags.allKeys containsObject:@"app_startup_type"]);
            XCTAssertTrue([field.allKeys containsObject:@"app_startup_duration"]);
        }

    }];
    [[FTMobileAgent sharedInstance] resetInstance];

}
- (void)testRumResourceData{
    [self setESConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        [NSThread sleepForTimeInterval:3];
        if (!error) {
        NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
        XCTAssertTrue(array.count == 2);
        [array enumerateObjectsUsingBlock:^(FTRecordModel *model, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dict = [FTJSONUtil ft_dictionaryWithJsonString:model.data];
            NSString *op = dict[@"op"];
            XCTAssertTrue([op isEqualToString:@"RUM"]);
            NSDictionary *opdata = dict[@"opdata"];
            NSString *measurement = opdata[@"measurement"];
            NSDictionary *tags = opdata[@"tags"];
            NSDictionary *field = opdata[@"field"];
            if ([measurement isEqualToString:@"rum_app_resource_performance"]) {
                [self rumInfluxDBtags:tags];
                XCTAssertTrue([tags.allKeys containsObject:@"resource_url_host"]&&[tags.allKeys containsObject:@"resource_type"]&&[tags.allKeys containsObject:@"response_server"]&&[tags.allKeys containsObject:@"response_content_type"]&&[tags.allKeys containsObject:@"resource_method"]&&[tags.allKeys containsObject:@"resource_status"]);
                XCTAssertTrue([field.allKeys containsObject:@"resource_size"]&&[field.allKeys containsObject:@"resource_load"]&&[field.allKeys containsObject:@"resource_dns"]&&[field.allKeys containsObject:@"resource_tcp"]&&[field.allKeys containsObject:@"resource_ssl"]&&[field.allKeys containsObject:@"resource_ttfb"]&&[field.allKeys containsObject:@"resource_trans"]);
            }else if([measurement isEqualToString:@"resource"]){
                [self rumEStags:tags];
                XCTAssertTrue([tags.allKeys containsObject:@"resource_url"]&&[tags.allKeys containsObject:@"resource_url_host"]&&[tags.allKeys containsObject:@"resource_url_path"]&&[tags.allKeys containsObject:@"resource_type"]&&[tags.allKeys containsObject:@"response_server"]&&[tags.allKeys containsObject:@"response_content_type"]&&[tags.allKeys containsObject:@"resource_method"]&&[tags.allKeys containsObject:@"resource_status"]);
                XCTAssertTrue([field.allKeys containsObject:@"request_header"]&&[field.allKeys containsObject:@"response_header"]&&[field.allKeys containsObject:@"resource_size"]&&[field.allKeys containsObject:@"resource_load"]&&[field.allKeys containsObject:@"resource_dns"]&&[field.allKeys containsObject:@"resource_tcp"]&&[field.allKeys containsObject:@"resource_ssl"]&&[field.allKeys containsObject:@"resource_ttfb"]&&[field.allKeys containsObject:@"resource_trans"]);
            
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
- (void)rumInfluxDBtags:(NSDictionary *)tags{
    XCTAssertTrue([tags.allKeys containsObject:@"app_id"]&&
                  [tags.allKeys containsObject:@"env"]&&
                  [tags.allKeys containsObject:@"version"]&&
                  [tags.allKeys containsObject:@"is_signin"]&&
                  [tags.allKeys containsObject:@"device"]&&
                  [tags.allKeys containsObject:@"model"]&&
                  [tags.allKeys containsObject:@"os"]&&
                  [tags.allKeys containsObject:@"screen_size"]&&
                  [tags.allKeys containsObject:@"app_name"]&&
                  [tags.allKeys containsObject:@"app_identifiedid"]&&
                  [tags.allKeys containsObject:@"network_type"]
                  );
}
- (void)rumEStags:(NSDictionary *)tags{
    XCTAssertTrue([tags.allKeys containsObject:@"app_id"]&&
                  [tags.allKeys containsObject:@"env"]&&
                  [tags.allKeys containsObject:@"version"]&&
                  [tags.allKeys containsObject:@"terminal"]&&
                  [tags.allKeys containsObject:@"source"]&&
                  [tags.allKeys containsObject:@"userid"]&&
                  [tags.allKeys containsObject:@"origin_id"]&&
                  [tags.allKeys containsObject:@"is_signin"]&&
                  [tags.allKeys containsObject:@"app_name"]&&
                  [tags.allKeys containsObject:@"app_identifiedid"]&&
                  [tags.allKeys containsObject:@"device"]&&
                  [tags.allKeys containsObject:@"model"]&&
                  [tags.allKeys containsObject:@"os"]&&
                  [tags.allKeys containsObject:@"os_version"]&&
                  [tags.allKeys containsObject:@"network_type"]&&
                  [tags.allKeys containsObject:@"device_uuid"]&&
                  [tags.allKeys containsObject:@"screen_size"]
                  );
}
- (void)setESConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.appid = self.appid;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];

}
@end
