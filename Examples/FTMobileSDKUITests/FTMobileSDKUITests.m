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
 * 模拟 APP 操作 产生相关数据，-testCrash 先执行
 */
- (void)testTraceUserActionUIExample {
    // UI tests must launch the application that they test.
    XCUIApplication *app = [[XCUIApplication alloc] init];
    ////将test 运行使用环境赋值给 application
    app.launchEnvironment =[[NSProcessInfo processInfo] environment];
    [app launch];//
    XCUIElementQuery *tablesQuery = app.tables;
    
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"NetworkTrace_clienthttp"]/*[[".cells[@\"NetworkTrace_clienthttp\"].staticTexts[@\"NetworkTrace_clienthttp\"]",".staticTexts[@\"NetworkTrace_clienthttp\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [NSThread sleepForTimeInterval:3];//等待网络请求回来
    [app.tables.staticTexts[@"TrackAppLongTask"] tap];
    [NSThread sleepForTimeInterval:10];

    [app.navigationBars[@"home"].buttons[@"home"] tap];

    [tablesQuery.staticTexts[@"TraceConsoleLog"] tap];

    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"BindUser"]/*[[".cells[@\"BindUser\"].staticTexts[@\"BindUser\"]",".staticTexts[@\"BindUser\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];

    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"EventFlowLog"]/*[[".cells[@\"EventFlowLog\"].staticTexts[@\"EventFlowLog\"]",".staticTexts[@\"EventFlowLog\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    
    XCUIElementQuery *segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [segmentedControlsQuery.buttons[@"first"] tap];
    [segmentedControlsQuery.buttons[@"second"] tap];
    [app/*@START_MENU_TOKEN@*/.buttons[@"FirstButton"]/*[[".scrollViews.buttons[@\"FirstButton\"]",".buttons[@\"FirstButton\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.staticTexts[@"FirstButton"] tap];
    [app/*@START_MENU_TOKEN@*/.buttons[@"SecondButton"]/*[[".scrollViews.buttons[@\"SecondButton\"]",".buttons[@\"SecondButton\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.staticTexts[@"SecondButton"] tap];
    [app/*@START_MENU_TOKEN@*/.steppers/*[[".scrollViews.steppers",".steppers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.buttons[@"Increment"] tap];

    XCUIElement *lableClickButton = app/*@START_MENU_TOKEN@*/.buttons[@"LABLE_CLICK"]/*[[".scrollViews.buttons[@\"LABLE_CLICK\"]",".buttons[@\"LABLE_CLICK\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [lableClickButton tap];

    XCUIElement *imageClickImage = app/*@START_MENU_TOKEN@*/.images[@"IMAGE_CLICK"]/*[[".scrollViews.images[@\"IMAGE_CLICK\"]",".images[@\"IMAGE_CLICK\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [imageClickImage tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 0"]/*[[".cells[@\"Row: 0\"].staticTexts[@\"Section: 0, Row: 0\"]",".staticTexts[@\"Section: 0, Row: 0\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [tablesQuery.staticTexts[@"Section: 0, Row: 1"] tap];

    [lableClickButton tap];
    [imageClickImage tap];
    
    [app/*@START_MENU_TOKEN@*/.buttons[@"result"]/*[[".scrollViews.buttons[@\"result\"]",".buttons[@\"result\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.staticTexts[@"result"] tap];
    //等待 10s 进行上传
    [NSThread sleepForTimeInterval:10];
            
    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
/**
  error 数据会在 - testTraceUserActionUIExample 方法中进行上传
 */
}


@end
