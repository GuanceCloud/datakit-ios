//
//  FTRUMActionTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/7.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "UIEvent+Mock.h"
#import "UIApplication+Test.h"
#import "UIApplication+FTAutoTrack.h"
#import "FTMobileAgent+Private.h"
#import "NSDate+FTUtil.h"
#import "FTTrackerEventDBTool.h"
#import "FTModelHelper.h"
#import "FTRecordModel.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "XCTestCase+Utils.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"

@interface FTRUMActionTest : XCTestCase
@property (nonatomic, strong) UIWindow *mockAppWindow;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@property (nonatomic, copy) NSString *track_id;
@end

@implementation FTRUMActionTest

- (void)setUp {
    _mockAppWindow = [[UIWindow alloc]initWithFrame:CGRectZero];
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    self.track_id = [processInfo environment][@"TRACK_ID"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self sdkInit];
}

- (void)tearDown {
    _mockAppWindow = nil;
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
}
- (void)sdkInit{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
#if TARGET_OS_TV
- (void)testTVOSActionName{
    [FTModelHelper startViewWithName:@"View"];
    
    UIView *pressView = [[UIView alloc]init];
    pressView.accessibilityIdentifier = @"test_press";
    [_mockAppWindow addSubview:pressView];
    UIPressesMock *press = [[UIPressesMock alloc]initWithPhase:UIPressPhaseEnded type:UIPressTypeMenu view:pressView];
    UIEvent *pressEvent = [UIEvent mockWithPress:press];
    [[UIApplication sharedApplication] ftSendEvent:pressEvent];
    
    [self waitForTimeInterval:0.2];
    
    UIView *selectView = [[UIView alloc]init];
    selectView.accessibilityIdentifier = @"test_select";
    [_mockAppWindow addSubview:selectView];
    UIPressesMock *select = [[UIPressesMock alloc]initWithPhase:UIPressPhaseEnded type:UIPressTypeSelect view:selectView];
    UIEvent *selectEvent = [UIEvent mockWithPress:select];
    
    [[UIApplication sharedApplication] ftSendEvent:selectEvent];
    
    [self waitForTimeInterval:0.2];
    
    UIView *playPauseView = [[UIView alloc]init];
    playPauseView.accessibilityIdentifier = @"test_playPause";
    [_mockAppWindow addSubview:playPauseView];
    UIPressesMock *playPause = [[UIPressesMock alloc]initWithPhase:UIPressPhaseEnded type:UIPressTypePlayPause view:playPauseView];
    UIEvent *playPauseEvent = [UIEvent mockWithPress:playPause];
    [[UIApplication sharedApplication] ftSendEvent:playPauseEvent];
    
    [FTModelHelper stopView];
    
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    
    NSArray *actionNames = @[@"[menu]",@"[play-pause]",@"[UIView](test_select)"];

    __block int count = 0;
    [FTModelHelper resolveModelArray:array callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_ACTION]) {
            if([actionNames containsObject:tags[FT_KEY_ACTION_NAME]]){
                count ++;
            }
        }
    }];
    XCTAssertTrue(count == 3);
    
}
#endif
@end
