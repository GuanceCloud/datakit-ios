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
#import <FTRUMManger.h>
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
    config.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
}
/**
 * 未设置 appid  ES 关闭
 * 验证： ES 数据不能正常写入
 */
-(void)testSetEmptyAppid{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count == oldArray.count);
}
/**
 * 设置允许追踪用户操作，目前支持应用启动和点击操作
 * 验证： Action 数据能正常写入
 */
- (void)testEnableTraceUserAction{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.appid = self.appid;
    config.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [self addESData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count >= oldArray.count);

}
/**
 * 设置不允许追踪用户操作
 * 验证： Action 数据不能正常写入
 */
- (void)testDisableTraceUserAction{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.appid = self.appid;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count == oldArray.count);

}
/**
 * 验证 source：view 的数据格式
 */
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
                [self rumTags:tags];
                NSDictionary *field = opdata[@"field"];
                XCTAssertTrue([field.allKeys containsObject:@"view_resource_count"]&&[field.allKeys containsObject:@"view_action_count"]&&[field.allKeys containsObject:@"view_long_task_count"]&&[field.allKeys containsObject:@"view_error_count"]);
                XCTAssertTrue([tags.allKeys containsObject:@"is_active"]&&[tags.allKeys containsObject:@"view_id"]&&[tags.allKeys containsObject:@"view_referrer"]&&[tags.allKeys containsObject:@"view_name"]);
                hasView = YES;
                *stop = YES;
            }
        }];
        XCTAssertTrue(hasView);
        [expectation fulfill];
    }];
   
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
  
}
/**
 * 验证 source：resource 的数据格式
 */
- (void)testResourceDataFormatChecks{
    NSArray *resourceTag = @[@"resource_url",
                             @"resource_url_host",
                             @"resource_url_path",
//                             @"resource_url_query",
                             @"resource_url_path_group",
                             @"resource_type",
                             @"resource_method",
                             @"resource_status",
                             @"resource_status_group",
    ];
    NSArray *resourceField = @[@"duration",
                               @"resource_size",
                               @"resource_dns",
                               @"resource_tcp",
                               @"resource_ssl",
                               @"resource_ttfb",
                               @"resource_trans",
                               @"resource_first_byte",
    ];
    [self setESConfig];
    
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        if (!error) {
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
                    NSDictionary *tags = opdata[@"tags"];
                    NSDictionary *field = opdata[@"field"];
                    [self rumTags:tags];
                    [resourceTag enumerateObjectsUsingBlock:^(NSString   *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        XCTAssertTrue([tags.allKeys containsObject:obj]);
                    }];
                    [resourceField enumerateObjectsUsingBlock:^(NSString   *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        XCTAssertTrue([field.allKeys containsObject:obj]);
                    }];
                    hasView = YES;
                    *stop = YES;
                }
            }];
            XCTAssertTrue(hasView);
        }
       
        [expectation fulfill];
    }];
   
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
/**
 * 验证 source：action 的数据格式
 */
- (void)testActionDataFormatChecks{
    [self setESConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    NSArray *oldArray =[[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
   
    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self.testVC.secondButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count>oldArray.count);
    [newArray enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"measurement"];
        if ([measurement isEqualToString:@"action"]) {
            NSDictionary *tags = opdata[@"tags"];
            NSDictionary *field = opdata[@"field"];
            [self rumTags:tags];
            XCTAssertTrue([field.allKeys containsObject:@"action_long_task_count"]&&[field.allKeys containsObject:@"action_resource_count"]&&[field.allKeys containsObject:@"action_error_count"]);
            XCTAssertTrue([tags.allKeys containsObject:@"action_id"]&&[tags.allKeys containsObject:@"action_name"]&&[tags.allKeys containsObject:@"action_type"]);
            XCTAssertTrue([tags.allKeys containsObject:@"view_id"]);
            XCTAssertTrue([tags.allKeys containsObject:@"view_referrer"]);
            XCTAssertTrue([tags.allKeys containsObject:@"view_name"]);
            XCTAssertTrue([tags.allKeys containsObject:@"session_id"]);
        }
    }];
}
/**
 * 验证 resource，action,error,long_task数据 是否同步到view中
 * error 为resource error
 */
- (void)testViewUpdate{
    [self setESConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self.testVC.secondButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self addLongTaskData];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    __block NSInteger resErrorCount = 0;
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        if (error) {
            resErrorCount = 1;
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [self addErrorData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasViewData = NO;

    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"measurement"];
        if ([measurement isEqualToString:@"view"]) {
            NSDictionary *field = opdata[@"field"];
            NSInteger actionCount = [field[@"view_action_count"] integerValue];
            NSInteger errorCount = [field[@"view_error_count"] integerValue];
            NSInteger resourceCount = [field[@"view_resource_count"] integerValue];
            NSInteger longTaskCount = [field[@"view_long_task_count"] integerValue];
            XCTAssertTrue(actionCount == 1);
            XCTAssertTrue(errorCount == (1+resErrorCount));
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == (1-resErrorCount));
            hasViewData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasViewData);

}
/**
 * 验证 resource,error,long_task数据 是否同步到action中
 */
- (void)testActionUpdate{
    [self setESConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [self.testVC.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    __block NSInteger resErrorCount = 0;
    [self networkUploadHandler:^(NSURLResponse *response, NSError *error) {
        if (error) {
            resErrorCount = 1;
        }
        [expectation fulfill];
    }];
    [self addLongTaskData];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [self addErrorData];
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_RUM];
    __block BOOL hasActionData = NO;
    [newArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSString *op = dict[@"op"];
        XCTAssertTrue([op isEqualToString:@"RUM"]);
        NSDictionary *opdata = dict[@"opdata"];
        NSString *measurement = opdata[@"measurement"];
        if ([measurement isEqualToString:@"action"]) {
            NSDictionary *field = opdata[@"field"];
            NSInteger errorCount = [field[@"action_error_count"] integerValue];
            NSInteger resourceCount = [field[@"action_resource_count"] integerValue];
            NSInteger longTaskCount = [field[@"action_long_task_count"] integerValue];
            XCTAssertTrue(errorCount == (1+resErrorCount));
            XCTAssertTrue(longTaskCount == 1);
            XCTAssertTrue(resourceCount == (1-resErrorCount));
            hasActionData = YES;
            *stop = YES;
        }
    }];
    XCTAssertTrue(hasActionData);

}

- (void)addErrorData{
   
    NSDictionary *field = @{@"error_message":@"-[__NSSingleObjectArrayI objectForKey:]: unrecognized selector sent to instance 0x600002ac5270",
                            @"error_stack":@"Slide_Address:74940416\nException Stack:\n0   CoreFoundation                      0x00007fff20421af6 __exceptionPreprocess + 242\n1   libobjc.A.dylib                     0x00007fff20177e78 objc_exception_throw + 48\n2   CoreFoundation                      0x00007fff204306f7 +[NSObject(NSObject) instanceMethodSignatureForSelector:] + 0\n3   CoreFoundation                      0x00007fff20426036 ___forwarding___ + 1489\n4   CoreFoundation                      0x00007fff20428068 _CF_forwarding_prep_0 + 120\n5   SampleApp                           0x000000010477fb06 __35-[Crasher throwUncaughtNSException]_block_invoke + 86\n6   libdispatch.dylib                   0x000000010561f7ec _dispatch_call_block_and_release + 12\n7   libdispatch.dylib                   0x00000001056209c8 _dispatch_client_callout + 8\n8   libdispatch.dylib                   0x0000000105622e46 _dispatch_queue_override_invoke + 1032\n9   libdispatch.dylib                   0x0000000105632508 _dispatch_root_queue_drain + 351\n10  libdispatch.dylib                   0x0000000105632e6d _dispatch_worker_thread2 + 135\n11  libsystem_pthread.dylib             0x00007fff611639f7 _pthread_wqthread + 220\n12  libsystem_pthread.dylib             0x00007fff61162b77 start_wqthread + 15"
    };
    NSDictionary *tag = @{
        @"error_source":@"logger",
        @"error_type":@"ios_crash"
    };
    NSString *invokeMethod = @"ftErrorWithtags:field:";
    SEL startMethod = NSSelectorFromString(invokeMethod);
    IMP imp = [[FTMobileAgent sharedInstance].rumManger methodForSelector:startMethod];
    void (*func)(id, SEL,id,id) = (void (*)(id,SEL,id,id))imp;
    func([FTMobileAgent sharedInstance].rumManger,startMethod,tag,field);
}
- (void)addLongTaskData{
    NSDictionary *field = @{@"duration":@5000000000,
                            @"long_task_stack":@"Backtrace of Thread 771:\n0 libsystem_kernel.dylib          0x7fff6112d756 __semwait_signal + 10\n1 libsystem_c.dylib               0x7fff200f7500 usleep + 53\n2 SampleApp                       0x1038b9a96 -[TestANRVC tableView:cellForRowAtIndexPath:] + 230\n3 UIKitCore                       0x7fff248ce1af -[UITableView _createPreparedCellForGlobalRow:withIndexPath:willDisplay:] + 865\n4 UIKitCore                       0x7fff248ce637 -[UITableView _createPreparedCellForRowAtIndexPath:willDisplay:] + 80\n5 UIKitCore                       0x7fff248dab61 -[UITableView _heightForRowAtIndexPath:] + 204\n6 UIKitCore                       0x7fff248eea95 -[UISectionRowData heightForRow:inSection:canGuess:] + 220\n7 UIKitCore                       0x7fff248f40ca -[UITableViewRowData heightForRow:inSection:canGuess:adjustForReorderedRow:] + 238\n8 UIKitCore                       0x7fff248f7c1a -[UITableViewRowData ensureHeightsFaultedInForScrollToIndexPath:boundsHeight:] + 864\n9 UIKitCore                       0x7fff248ad10f -[UITableView _contentOffsetForScrollingToRowAtIndexPath:atScrollPosition:usingPresentationValues:] + 1138\n10 UIKitCore                       0x7fff248ae07c -[UITableView _scrollToRowAtIndexPath:atScrollPosition:animated:usingPresentationValues:] + 142\n11 UIKitCore                       0x7fff248b18dc -[UITableView _selectRowAtIndexPath:animated:scrollPosition:notifyDelegate:isCellMultiSelect:] + 719\n12 UIKitCore                       0x7fff248b2004 -[UITableView selectRowAtIndexPath:animated:scrollPosition:] + 91\n"
        
    };
    
    NSString *invokeMethod = @"ftLongTaskWithtags:field:";
    SEL startMethod = NSSelectorFromString(invokeMethod);
    IMP imp = [[FTMobileAgent sharedInstance].rumManger methodForSelector:startMethod];
    void (*func)(id, SEL,id,id) = (void (*)(id,SEL,id,id))imp;
    func([FTMobileAgent sharedInstance].rumManger,startMethod,@{},field);
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
