//
//  FTRUMConfigurationTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/7/25.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTRumConfig.h"
#import "FTMobileConfig+Private.h"
#import "FTMobileAgent+Private.h"
#import "FTTrackerEventDBTool+Test.h"
#import "FTRecordModel.h"
#import "FTConstants.h"
#import "FTTrackDataManager+Test.h"
#import "FTModelHelper.h"
#import "FTGlobalRumManager.h"
#import "FTRUMManager.h"
#import "FTAutoTrackHandler.h"
#import "XCTestCase+Utils.h"

@interface ModalViewController : UIViewController

@end

@implementation ModalViewController


@end
@interface FTRUMConfigurationTest : XCTestCase
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTRUMConfigurationTest

-(void)setUp{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
-(void)tearDown{
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    [FTMobileAgent shutDown];
}

- (void)testRUMFreezeThreshold{
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:@"appid"];
    XCTAssertTrue(rumConfig.freezeDurationMs == 250);
    rumConfig.freezeDurationMs = 0;
    XCTAssertTrue(rumConfig.freezeDurationMs == 100);
    rumConfig.freezeDurationMs = 5000;
    XCTAssertTrue(rumConfig.freezeDurationMs == 5000);
}
- (void)testDiscardNew{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.rumCacheLimitCount = 1000;
    rumConfig.rumDiscardType = FTRUMDiscard;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    for (int i = 0; i<10010; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_RUM;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertTrue([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 10000);
}

- (void)testDiscardOldBulk{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.autoSync = NO;
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.rumCacheLimitCount = 1000;
    rumConfig.rumDiscardType = FTRUMDiscardOldest;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];

    for (int i = 0; i<10010; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_RUM;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManager sharedInstance] addTrackData:model type:FTAddDataRUM];

    }
    [[FTTrackDataManager sharedInstance] insertCacheToDB];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithType:FT_DATA_TYPE_RUM];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_RUM] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 10000);
}
- (void)testAddPkgInfo{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [config addPkgInfo:@"test_sdk" value:@"1.0.0"];
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [FTModelHelper addActionWithContext:nil];
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(newArray.count >= 1);
    __block BOOL hasActionData = NO;
    [FTModelHelper resolveModelArray:newArray callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        XCTAssertTrue([tags[FT_SDK_PKG_INFO] isEqualToDictionary:@{@"test_sdk":@"1.0.0"}]);
        hasActionData = YES;
        *stop = YES;
    }];
    XCTAssertTrue(hasActionData);
}

- (void)testViewTrackingStrategy_disableTraceUserView{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = NO;
    __block BOOL noView = YES;
    rumConfig.viewTrackingStrategy = ^FTRumView * _Nullable(UIViewController * _Nonnull viewController) {
        FTRumView *rumView = [[FTRumView alloc]initWithViewName:[NSString stringWithFormat:@"test:%@",NSStringFromClass(viewController.class)]];
        noView = NO;
        return rumView;
    };
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];

    UIViewController *vc = [[UIViewController alloc]init];

    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];
    
    XCTAssertTrue(noView);
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    XCTAssertTrue(count == newCount);
}
- (void)testViewTrackingStrategy_enableTraceUserView{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    __block BOOL noView = YES;
    rumConfig.viewTrackingStrategy = ^FTRumView * _Nullable(UIViewController * _Nonnull viewController) {
        FTRumView *rumView = [[FTRumView alloc]initWithViewName:[NSString stringWithFormat:@"test:%@",NSStringFromClass(viewController.class)] property:@{@"test_strategy":@"enableTraceUserView"}];
        noView = NO;
        return rumView;
    };
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
   
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    UIViewController *vc = [[UIViewController alloc]init];

    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];
    
    XCTAssertTrue(noView == NO);
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    
    XCTAssertTrue(datas.count > count);
    
    [FTModelHelper resolveModelArray:datas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            NSString *viewName = tags[FT_KEY_VIEW_NAME];
            XCTAssertTrue([viewName isEqualToString:@"test:UIViewController"]);
            XCTAssertTrue([fields[@"test_strategy"] isEqualToString:@"enableTraceUserView"]);
        }
    }];
}

- (void)testViewTrackingStrategy_return_nil{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    rumConfig.viewTrackingStrategy = ^FTRumView * _Nullable(UIViewController * _Nonnull viewController) {
        return nil;
    };
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    UIViewController *vc = [[UIViewController alloc]init];
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    XCTAssertTrue(count == newCount);
}

- (void)testViewTrackingStrategy_rumView_isUntrackedModal{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:self.url];
    config.enableSDKDebugLog = YES;
    config.autoSync = NO;
    [FTMobileAgent startWithConfigOptions:config];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    rumConfig.enableTraceUserView = YES;
    rumConfig.viewTrackingStrategy = ^FTRumView * _Nullable(UIViewController * _Nonnull viewController) {
        FTRumView *rumView = [[FTRumView alloc]initWithViewName:[NSString stringWithFormat:@"test:%@",NSStringFromClass(viewController.class)]];
        rumView.isUntrackedModal = [viewController isKindOfClass:ModalViewController.class];
        return rumView;
    };
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    
    UIViewController *vc = [[UIViewController alloc]init];
    NSInteger count = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    ModalViewController *modalVC = [[ModalViewController alloc]init];

    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:vc animated:YES];
    
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidAppear:modalVC animated:YES];
    [self waitForTimeInterval:0.1];
    [[FTAutoTrackHandler sharedInstance].viewControllerHandler notify_viewDidDisappear:modalVC animated:YES];
    
    [[FTGlobalRumManager sharedInstance].rumManager syncProcess];
    NSArray *datas =[[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
    XCTAssertTrue(datas.count > count);
    NSMutableSet *set = [[NSMutableSet alloc]init];
    [FTModelHelper resolveModelArray:datas callBack:^(NSString * _Nonnull source, NSDictionary * _Nonnull tags, NSDictionary * _Nonnull fields, BOOL * _Nonnull stop) {
        if ([source isEqualToString:FT_RUM_SOURCE_VIEW]) {
            [set addObject:tags[FT_KEY_VIEW_ID]];
            XCTAssertTrue([tags[FT_KEY_VIEW_NAME] isEqualToString:@"test:UIViewController"]);
        }
    }];
    XCTAssertTrue(set.count == 2);
}

@end
