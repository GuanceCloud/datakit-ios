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
    
    [app launch];
    
    [app.buttons[@"track"] tap];
    [app.buttons[@"button 1"] tap];
    [app.buttons[@"button 2"] tap];
    [app.staticTexts[@"lab"] tap];
    [[[[[[[[[[app childrenMatchingType:XCUIElementTypeWindow] elementBoundByIndex:0] childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element childrenMatchingType:XCUIElementTypeOther].element tap];
    
    XCUIElementQuery *tablesQuery = app.tables;
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"tableView Cell 0"]/*[[".cells.staticTexts[@\"tableView Cell 0\"]",".staticTexts[@\"tableView Cell 0\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"tableView Cell 2"]/*[[".cells.staticTexts[@\"tableView Cell 2\"]",".staticTexts[@\"tableView Cell 2\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"tableView Cell 1"]/*[[".cells.staticTexts[@\"tableView Cell 1\"]",".staticTexts[@\"tableView Cell 1\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    
    XCUIElementQuery *segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [segmentedControlsQuery.buttons[@"first"] tap];
    [segmentedControlsQuery.buttons[@"second"] tap];
    [segmentedControlsQuery.buttons[@"third"] tap];
    
    XCUIApplication *app2 = app;
    [app2/*@START_MENU_TOKEN@*/.buttons[@"FirstButton"]/*[[".scrollViews.buttons[@\"FirstButton\"]",".buttons[@\"FirstButton\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [app2/*@START_MENU_TOKEN@*/.buttons[@"SecondButton"]/*[[".scrollViews.buttons[@\"SecondButton\"]",".buttons[@\"SecondButton\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    
    XCUIElementQuery *steppersQuery = app2/*@START_MENU_TOKEN@*/.steppers/*[[".scrollViews.steppers",".steppers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [steppersQuery.buttons[@"Decrement"] tap];
    [steppersQuery.buttons[@"Increment"] tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 0"]/*[[".cells.staticTexts[@\"Section: 0, Row: 0\"]",".staticTexts[@\"Section: 0, Row: 0\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 1"]/*[[".cells.staticTexts[@\"Section: 0, Row: 1\"]",".staticTexts[@\"Section: 0, Row: 1\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 2"]/*[[".cells.staticTexts[@\"Section: 0, Row: 2\"]",".staticTexts[@\"Section: 0, Row: 2\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [app.navigationBars[@"testUI"].buttons[@"Back"] tap];
    [app.navigationBars[@"Test4View"].buttons[@"Back"] tap];
    [app.buttons[@"result"] tap];
    XCUIElement *lab = app.staticTexts[@"All Right"];
    
    XCTAssertNil(lab,@"Track Fail");
     
    
    // Use recording to get started writing UI tests.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}
- (void)testBtnClick{
    

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
