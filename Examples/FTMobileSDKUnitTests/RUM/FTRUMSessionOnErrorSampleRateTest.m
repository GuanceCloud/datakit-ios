//
//  FTRUMSessionOnErrorSampleRateTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/3/18.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Utils.h"
#import "FTTrackerEventDBTool.h"
#import "FTMobileAgent.h"
#import "FTBaseInfoHandler.h"
#import "FTModelHelper.h"
#import "FTConstants.h"
#import "FTRUMManager.h"
#import "FTGlobalRumManager.h"
@interface FTRUMSessionOnErrorSampleRateTest : XCTestCase
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTRUMSessionOnErrorSampleRateTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FTMobileAgent shutDown];
}
- (void)sdkInitWithRumSampleRate:(int)sampleRate{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.samplerate = sampleRate;
    rumConfig.sessionOnErrorSampleRate = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
}
- (void)testSessionOnErrorSampleRate_sampling{
    [self sdkInitWithRumSampleRate:100];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_sampling" stack:@"testSessionOnErrorSampleRate_sampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"sampling"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == NO);
    }];
}
- (void)testSessionOnErrorSampleRate_unsampling{
    [self sdkInitWithRumSampleRate:0];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_sampling" stack:@"testSessionOnErrorSampleRate_sampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"unsampling"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasError = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"unsampling"]);
        }
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == YES);
    }];
    XCTAssertTrue(hasError == YES);
    XCTAssertTrue(hasView == NO);
    XCTAssertTrue(hasAction == YES);
}
- (void)testSessionOnErrorSampleRate_resource_error{
    [self sdkInitWithRumSampleRate:0];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [FTModelHelper startResource:@"111"];
    [FTModelHelper stopErrorResource:@"111"];
    [FTModelHelper addActionWithContext:@{@"test":@"resource_error"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];

    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasError = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"resource_error"]);
        }
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == YES);
    }];
    XCTAssertTrue(hasError == YES);
    XCTAssertTrue(hasView == NO);
    XCTAssertTrue(hasAction == YES);
}
- (void)testSessionOnErrorSampleRate_error{
    [self sdkInitWithRumSampleRate:0];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];

    [FTModelHelper startView:@{@"test":@"sampling"}];
    [[FTExternalDataManager sharedManager] addErrorWithType:@"test" message:@"testSessionOnErrorSampleRate_sampling" stack:@"testSessionOnErrorSampleRate_sampling"];
    [FTModelHelper addActionWithContext:@{@"test":@"error"}];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getAllDatas];
    XCTAssertTrue(newArray.count>oldArray.count);
    __block BOOL hasError = NO;
    __block BOOL hasView = NO;
    __block BOOL hasAction= NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if([source isEqualToString:FT_RUM_SOURCE_ERROR]){
            hasError = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_VIEW]){
            hasView = YES;
        }else if ([source isEqualToString:FT_RUM_SOURCE_ACTION]){
            hasAction = YES;
            XCTAssertTrue([fields[@"test"] isEqualToString:@"error"]);
        }
        XCTAssertTrue([tags[FT_RUM_KEY_IS_ERROR_SESSION] boolValue] == YES);
    }];
    XCTAssertTrue(hasError == YES);
    XCTAssertTrue(hasView == NO);
    XCTAssertTrue(hasAction == YES);
    
}
@end
