//
//  ft_sdk_iosTestUITests.m
//  ft-sdk-iosTestUITests
//
//  Created by 胡蕾蕾 on 2019/12/25.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>

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
- (void)testExample {
   
    // UI tests must launch the application that they test.
    XCUIApplication *app = [[XCUIApplication alloc] init];
    XCUIElement *window = [app.windows elementBoundByIndex:0];

    [app launch];
    
    
    [app.buttons[@"login"] tap];
    [app.buttons[@"button 1"] tap];
    [app.buttons[@"button 2"] tap];
    [app.buttons[@"lab"] tap];
    
    XCUIElementQuery *tablesQuery = app.tables;
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"tableView Cell 0"]/*[[".cells.staticTexts[@\"tableView Cell 0\"]",".staticTexts[@\"tableView Cell 0\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"tableView Cell 1"]/*[[".cells.staticTexts[@\"tableView Cell 1\"]",".staticTexts[@\"tableView Cell 1\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    
    XCUIElementQuery *segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [segmentedControlsQuery.buttons[@"first"] tap];
    [segmentedControlsQuery.buttons[@"second"] tap];
    [segmentedControlsQuery.buttons[@"third"] tap];
    
    XCUIApplication *app2 = app;
    [app2/*@START_MENU_TOKEN@*/.buttons[@"SecondButton"]/*[[".scrollViews.buttons[@\"SecondButton\"]",".buttons[@\"SecondButton\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    XCUIElementQuery *steppersQuery = app2/*@START_MENU_TOKEN@*/.steppers/*[[".scrollViews.steppers",".steppers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [steppersQuery.buttons[@"Increment"] tap];
    [steppersQuery.buttons[@"Decrement"] tap];
    [app2/*@START_MENU_TOKEN@*/.buttons[@"lable"]/*[[".scrollViews.buttons[@\"lable\"]",".buttons[@\"lable\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [[app.scrollViews childrenMatchingType:XCUIElementTypeImage].element tap];
    [tablesQuery.staticTexts[@"Section: 0, Row: 0"] tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 1"]/*[[".cells.staticTexts[@\"Section: 0, Row: 1\"]",".staticTexts[@\"Section: 0, Row: 1\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [app.navigationBars[@"testUI"].buttons[@"icon back"] tap];
    [app.navigationBars[@"home"].buttons[@"icon back"] tap];
    [app.buttons[@"result logout"] tap];

    

    [window pressForDuration:120];
    XCUIElement *success = app.buttons[@"buttons"];
       //判断是否登陆
    XCTAssertTrue(success.exists);
    // 1 、  8  、 19
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
