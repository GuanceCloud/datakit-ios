//
//  ft_sdk_iosTestUITests.m
//  ft-sdk-iosTestUITests
//
//  Created by 胡蕾蕾 on 2019/12/25.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface FTMobileSDKUITests : XCTestCase

@end

@implementation FTMobileSDKUITests

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
  测试全埋点流程 请设置 enableTrackScreenFlow = NO;
 */
//- (void)testAutoTrackUIExample {
//    // UI tests must launch the application that they test.
//    XCUIApplication *app = [[XCUIApplication alloc] init];
//    XCUIElement *window = [app.windows elementBoundByIndex:0];
//    ////将test 运行使用环境赋值给 application
//    app.launchEnvironment =[[NSProcessInfo processInfo] environment];
//    [app launch];
//    
//   
//    
//    XCUIElementQuery *tablesQuery = app.tables;
////    [tablesQuery.staticTexts[@"BindUser"] tap];
//    [tablesQuery.staticTexts[@"Test_autoTrack"] tap];
//        
//    XCUIElementQuery *segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
//    [segmentedControlsQuery.buttons[@"first"] tap];
//    [segmentedControlsQuery.buttons[@"second"] tap];
//    [segmentedControlsQuery.buttons[@"third"] tap];
//    
//    XCUIElementQuery *steppersQuery = app/*@START_MENU_TOKEN@*/.steppers/*[[".scrollViews.steppers",".steppers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
//    [steppersQuery.buttons[@"Increment"] tap];
//    [steppersQuery.buttons[@"Decrement"] tap];
//    
//    XCUIApplication *app2 = app;
//    [app2.buttons[@"lable"] tap];
//    [[app.scrollViews childrenMatchingType:XCUIElementTypeImage].element tap];
//    
//    XCUIElementQuery *tablesQuery2 = app2.tables;
//    [tablesQuery2.staticTexts[@"Section: 0, Row: 0"] pressForDuration:2];
//    [tablesQuery2.staticTexts[@"Section: 0, Row: 1"] pressForDuration:2];
//    [app2.buttons[@"result"] tap];
//
//   
//    [window pressForDuration:70];
//    XCUIElement *success = app.staticTexts[@"SUCCESS"];
//         //判断上传成功数量 与 实际上传数量是否相等
//    XCTAssertTrue(success.exists);
//    
//    // Use recording to get started writing UI tests.
//    // Use XCTAssert and related functions to verify your tests produce the correct results.
//}

- (void)testCrash{
    XCUIApplication *app = [[XCUIApplication alloc] init];
    XCUIElement *window = [app.windows elementBoundByIndex:0];
    ////将test 运行使用环境赋值给 application
    app.launchEnvironment =[[NSProcessInfo processInfo] environment];
    [app launch];
    
    [app.tables.staticTexts[@"Test_crashLog"] tap];
    [NSThread sleepForTimeInterval:3];
    XCUIElement *success  = app.alerts[@"Crash"];
    
    XCTAssertTrue(success.exists);
    
}



@end
