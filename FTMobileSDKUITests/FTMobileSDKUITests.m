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
 * 测试action、view数据采集
 * enableTraceUserAction = YES;
 */
//- (void)testTraceUserActionUIExample {
//    // UI tests must launch the application that they test.
//    XCUIApplication *app = [[XCUIApplication alloc] init];
//    XCUIElement *window = [app.windows elementBoundByIndex:0];
//    ////将test 运行使用环境赋值给 application
//    app.launchEnvironment =[[NSProcessInfo processInfo] environment];
//    [app launch];//
//    XCUIElementQuery *tablesQuery = app.tables;
//    XCUIElement *networktraceClienthttpStaticText = tablesQuery.staticTexts[@"NetworkTrace_clienthttp"];
//    [networktraceClienthttpStaticText tap];
//
//    [tablesQuery.staticTexts[@"EventFlowLog"] tap];
//    
//    XCUIElementQuery *segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
//    [segmentedControlsQuery.buttons[@"first"] tap];
//    [segmentedControlsQuery.buttons[@"second"] tap];
//    [segmentedControlsQuery.buttons[@"third"] tap];
//    
//    [app/*@START_MENU_TOKEN@*/.steppers/*[[".scrollViews.steppers",".steppers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.buttons[@"Increment"] tap];
//    
//    
//    XCUIElementQuery *tablesQuery2 = app.tables;
//    [tablesQuery2/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 0"]/*[[".cells.staticTexts[@\"Section: 0, Row: 0\"]",".staticTexts[@\"Section: 0, Row: 0\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
//    [tablesQuery2/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 1"]/*[[".cells.staticTexts[@\"Section: 0, Row: 1\"]",".staticTexts[@\"Section: 0, Row: 1\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
//    [[[XCUIApplication alloc] init].buttons[@"result"].staticTexts[@"result"] tap];
//        
//   
//    [window pressForDuration:6];
//
//    // Use recording to get started writing UI tests.
//    // Use XCTAssert and related functions to verify your tests produce the correct results.
//}
- (void)testCrash{
    XCUIApplication *app = [[XCUIApplication alloc] init];
    ////将test 运行使用环境赋值给 application
    app.launchEnvironment =[[NSProcessInfo processInfo] environment];
    [app launch];
    
    [app.tables.staticTexts[@"TrackAppCrash"] tap];
    XCUIElementQuery *tablesQuery2 = app.tables;

    [tablesQuery2.staticTexts[@"throwUncaughtNSException"] tap];

    [NSThread sleepForTimeInterval:3];
    XCUIElement *success  = app.alerts[@"Crash"];
    
    XCTAssertTrue(success.exists);
    
}



@end
