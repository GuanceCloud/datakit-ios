//
//  ft_sdk_testUserBind.m
//  ft-sdk-iosTestUITests
//
//  Created by 胡蕾蕾 on 2020/2/6.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface ft_sdk_testUserBind : XCTestCase

@end

@implementation ft_sdk_testUserBind

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;

    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testWhiteBlackListAndBindUser{
    // 配置 appdelegate 中的 config 来进行autotrack测试 与 黑名单白名单测试
    XCUIApplication *app = [[XCUIApplication alloc] init];
    XCUIElement *window = [app.windows elementBoundByIndex:0];

    [app launch];
        
    
    [app.buttons[@"start"] tap];
    
    XCUIElementQuery *segmentedControlsQuery = app/*@START_MENU_TOKEN@*/.segmentedControls/*[[".scrollViews.segmentedControls",".segmentedControls"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [segmentedControlsQuery.buttons[@"first"] tap];
    [segmentedControlsQuery.buttons[@"second"] tap];
    [segmentedControlsQuery.buttons[@"third"] tap];
    
    XCUIElementQuery *steppersQuery = app/*@START_MENU_TOKEN@*/.steppers/*[[".scrollViews.steppers",".steppers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/;
    [steppersQuery.buttons[@"Increment"] tap];
    [steppersQuery.buttons[@"Decrement"] tap];
    
    [app/*@START_MENU_TOKEN@*/.buttons[@"lable"]/*[[".scrollViews.buttons[@\"lable\"]",".buttons[@\"lable\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [[app.scrollViews childrenMatchingType:XCUIElementTypeImage].element tap];
    
    XCUIElementQuery *tablesQuery = app.tables;
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 0"]/*[[".cells.staticTexts[@\"Section: 0, Row: 0\"]",".staticTexts[@\"Section: 0, Row: 0\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [tablesQuery/*@START_MENU_TOKEN@*/.staticTexts[@"Section: 0, Row: 1"]/*[[".cells.staticTexts[@\"Section: 0, Row: 1\"]",".staticTexts[@\"Section: 0, Row: 1\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ tap];
    [app.navigationBars[@"testUI"].buttons[@"icon back"] tap];
    [app.buttons[@"result logout"] tap];
    XCUIElement *list = app.staticTexts[@"WhiteBlackList"];
    //  判断黑白名单设置 数据库总数 == 记录各个事件数  未登录状态
    XCTAssertTrue(list.exists);
    [app.navigationBars[@"Result"].buttons[@"icon back"] tap];
    [app.buttons[@"login"] tap];
    
    XCUIElement *bind = app.staticTexts[@"bindUser"];
    [window pressForDuration:10];
    //验证 绑定用户成功    绑定用户后 会上传数据库数据
    XCTAssertTrue(bind.exists);

    
}
@end
