//
//  FTRUMViewTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/21.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTAutoTrackHandler.h"
#import "AddRumDatasHandlerMock.h"
#import "XCTestCase+Utils.h"

@interface FTRUMViewTest : XCTestCase

@end

@implementation FTRUMViewTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTAutoTrackHandler sharedInstance] shutDown];

}
- (void)testEnableAutoTrackView{
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    XCTAssertTrue([FTAutoTrackHandler sharedInstance].viewControllerHandler != nil);
}
- (void)testDisableAutoTrackView{
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:NO action:NO];
    
    XCTAssertNil([FTAutoTrackHandler sharedInstance].viewControllerHandler);
}
- (void)testViewDidAppear{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    UIViewController *vc = [[UIViewController alloc]init];
    
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];
    
    XCTAssertTrue(handler.viewStartCount == 1);
    
}
- (void)testViewDidAppear_itStopsPreviousRUMView{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    UIViewController *vc = [[UIViewController alloc]init];
    UIViewController *vc2 = [[UIViewController alloc]init];

    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc2 animated:YES];

    XCTAssertTrue(handler.viewStartCount == 2);
    XCTAssertTrue(handler.viewStopCount == 1);

}
- (void)testViewDidAppear_itDoesNotStartTheSameRUMViewTwice{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    UIViewController *vc = [[UIViewController alloc]init];
    
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];

    XCTAssertTrue(handler.viewStartCount == 1);
    XCTAssertTrue(handler.viewStopCount == 0);
}

- (void)testWhenViewDidDisappear_itStartsPreviousRUMView{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    UIViewController *vc = [[UIViewController alloc]init];
    [vc viewDidAppear:YES];
    UIViewController *vc2 = [[UIViewController alloc]init];
    [vc2 viewDidAppear:YES];
    [vc2 viewDidDisappear:YES];


    XCTAssertTrue(handler.viewStartCount == 3);
    XCTAssertTrue(handler.viewStopCount == 2);
    XCTAssertTrue(handler.array[0].type == ViewStart);
    XCTAssertTrue(handler.array[1].type == ViewStop);
    XCTAssertTrue(handler.array[2].type == ViewStart);
    XCTAssertTrue(handler.array[3].type == ViewStop);
    XCTAssertTrue(handler.array[4].type == ViewStart);

    XCTAssertFalse([handler.array[2].viewId isEqualToString:handler.array[4].viewId]);
}
- (void)testWhenViewDidDisappear_itDoesNotStartAnyRUMView{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    UIViewController *vc = [[UIViewController alloc]init];
    [vc viewDidAppear:YES];
   


    XCTAssertTrue(handler.viewStartCount == 1);
    XCTAssertTrue(handler.viewStopCount == 0);
}
- (void)testWhenViewDidDisappearButPreviousView_itDoesNotStartAnyRUMView{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    UIViewController *vc = [[UIViewController alloc]init];
    [vc viewDidDisappear:YES];
   

    XCTAssertTrue(handler.viewStartCount == 0);
    XCTAssertTrue(handler.viewStopCount == 0);
}
- (void)testWhenAppStateChanges_itStopsAndRestartsRUMView{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    
    UIViewController *vc = [[UIViewController alloc]init];
    [vc viewDidAppear:YES];
   
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self waitForTimeInterval:0.2];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    XCTAssertTrue(handler.viewStartCount == 2);
    XCTAssertTrue(handler.viewStopCount == 1);
    XCTAssertTrue(handler.array[0].type == ViewStart);
    XCTAssertTrue(handler.array[1].type == ViewStop);
    XCTAssertTrue(handler.array[2].type == ViewStart);
    XCTAssertTrue([handler.array[0].viewId isEqualToString:handler.array[1].viewId]);
    XCTAssertFalse([handler.array[0].viewId isEqualToString:handler.array[2].viewId]);
}
- (void)testGivenViewControllerDidNotStart_whenAppStateChanges_itDoesNothing{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    

   
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self waitForTimeInterval:0.2];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
    
    XCTAssertTrue(handler.viewStartCount == 0);
    XCTAssertTrue(handler.viewStopCount == 0);
}
- (void)testParentViewIsNavigationController{
    AddRumDatasHandlerMock *handler = [[AddRumDatasHandlerMock alloc]init];
    [FTAutoTrackHandler sharedInstance].addRumDatasDelegate = handler;
    [[FTAutoTrackHandler sharedInstance] startWithTrackView:YES action:NO];
    UIViewController *vc = [[UIViewController alloc]init];

    UINavigationController *nav = [[UINavigationController alloc]initWithRootViewController:vc];
    [nav viewDidLoad];
    [vc viewDidLoad];
    [nav viewDidAppear:YES];
    [vc viewDidAppear:YES];
    
    XCTAssertTrue(handler.viewStartCount == 1);
    XCTAssertTrue(handler.viewStopCount == 0);
}
@end
