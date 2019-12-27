//
//  FTAutoTrackTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/25.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIViewController+ZY_RootVC.h>
#import <UIView+ZY_currentController.h>
#import "UITestVC.h"
#import <ZYTrackerEventDBTool.h>

@interface FTAutoTrackTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *viewController;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation FTAutoTrackTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];

    self.viewController = [[UITestVC alloc] init];

    self.tabBarController = [[UITabBarController alloc] init];

    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
    self.navigationController.tabBarItem.title = @"UITestVC";

    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;

    [self.viewController view];
    [self.viewController viewWillAppear:NO];
    [self.viewController viewDidAppear:NO];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[ZYTrackerEventDBTool sharedManger] getDatasCount];
    NSLog(@"ZYTrackerEventDBTool == %ld", (long)[[ZYTrackerEventDBTool sharedManger] getDatasCount]);
}

- (void)testExample {
    [self.viewController.firstButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    
    [self.viewController.secondButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}
- (void)testControllerOfTheView{
      UIViewController *currentVC = [self.viewController.firstButton zy_getCurrentViewController];
      XCTAssertEqualObjects(self.viewController, currentVC);

}
- (void)testRootViewControllerOfTheView{

      NSString *rootStr = [UIViewController zy_getRootViewController];
      XCTAssertTrue([rootStr isEqualToString:@"UINavigationController"]);

}

@end
