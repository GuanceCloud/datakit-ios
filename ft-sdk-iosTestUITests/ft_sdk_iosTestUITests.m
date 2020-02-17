//
//  ft_sdk_iosTestUITests.m
//  ft-sdk-iosTestUITests
//
//  Created by 胡蕾蕾 on 2019/12/25.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestAccount.h"

@interface ft_sdk_iosTestUITests : XCTestCase

@end

@implementation ft_sdk_iosTestUITests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
      self.continueAfterFailure = NO;
    
    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
   
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
/**
  测试全埋点流程
 */
- (void)testAutoTrackUIExample {
    // UI tests must launch the application that they test.
    XCUIApplication *app = [[XCUIApplication alloc] init];
    XCUIElement *window = [app.windows elementBoundByIndex:0];

    [app launch];
    NSString *account = FTTestAccount;
    NSString *password =FTTestPassword;
    //请在TestAccount.h 配置DataFlux账号密码 用以获取真实上传数据数量 与本地上传进行比对
    if (account.length>0 && password.length>0) {
    [app.buttons[@"start"] tap];
    
    XCUIElementQuery *segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [segmentedControlsQuery.buttons[@"first"] tap];
    [segmentedControlsQuery.buttons[@"second"] tap];
    [segmentedControlsQuery.buttons[@"third"] tap];
    
    XCUIElementQuery *steppersQuery = app/*@START_MENU_TOKEN@*/.steppers/*[[".scrollViews.steppers",".steppers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [steppersQuery.buttons[@"Increment"] tap];
    [steppersQuery.buttons[@"Decrement"] tap];
    
    XCUIApplication *app2 = app;
    [app2/*@START_MENU_TOKEN@*/.buttons[@"lable"]/*[[".scrollViews.buttons[@\"lable\"]",".buttons[@\"lable\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [[app.scrollViews childrenMatchingType:XCUIElementTypeImage].element tap];
    
    XCUIElementQuery *tablesQuery = app2.tables;
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 0"]/*[[".cells.staticTexts[@\"Section: 0, Row: 0\"]",".staticTexts[@\"Section: 0, Row: 0\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ pressForDuration:2];
    [tablesQuery.staticTexts[@"Section: 0, Row: 1"] pressForDuration:2];
    [app.navigationBars[@"testUI"].buttons[@"icon back"] tap];

    
    [app.buttons[@"result logout"] tap];
  
   
    [window pressForDuration:100];
    XCUIElement *success = app.staticTexts[@"SUCCESS"];
         //判断上传成功数量 与 实际上传数量是否相等
    XCTAssertTrue(success.exists);
    }else{
    XCTFail(@"需要DataFlux账号密码");
    }
    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}



- (void)testLaunchPerformance {
    if (@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)) {
        // This measures how long it takes to launch your application.
        [self measureWithMetrics:@[XCTOSSignpostMetric.applicationLaunchMetric] block:^{
            [[[XCUIApplication alloc] init] launch];
        }];
    }
}

@end
