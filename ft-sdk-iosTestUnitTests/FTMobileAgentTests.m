//
//  ft_sdk_iosTestUnitTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/19.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <ZYDataBase/ZYTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <ZYBaseInfoHander.h>
#import <FTRecordModel.h>
#import <FTLocationManager.h>
#import "AppDelegate.h"
#import <FTUploadTool.h>
@interface FTMobileAgentTests : XCTestCase
@property (nonatomic, strong) FTMobileConfig *config;
@end


@implementation FTMobileAgentTests

- (void)setUp {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    self.config = appDelegate.config;
     
   
    [[FTMobileAgent sharedInstance] logout];
               NSDictionary *data= @{
                   @"op" : @"cstm",
                   @"opdata" :@{
                           @"field" :@"pushFile",
                           @"tags":@{
                                   @"pushVC":@"Test4ViewController",
                       },
                   @"values":@{
                              @"event" :@"Gesture",
                       },
                   },
               } ;
               FTRecordModel *model = [FTRecordModel new];
               model.tm = [ZYBaseInfoHander getCurrentTimestamp];
               model.data =[ZYBaseInfoHander convertToJsonData:data];
               [[ZYTrackerEventDBTool sharedManger] insertItemWithItemData:model];
               
               NSDictionary *data2 = @{
                   @"cpn":@"Test4ViewController",
                   @"op": @"click",
                   @"opdata":@{
                           @"vtp": @"UIWindow[7]/UITransitionView[6]/UIDropShadowView[5]/UILayoutContainerView[4]/UINavigationTransitionView[3]/UIViewControllerWrapperView[2]/UIView[1]/UITableView[0]",
                   },
                   @"rpn":@"UINavigationController",
               };
               FTRecordModel *model2 = [FTRecordModel new];
               model2.tm = [ZYBaseInfoHander getCurrentTimestamp];
               model2.data =[ZYBaseInfoHander convertToJsonData:data2];
               [[ZYTrackerEventDBTool sharedManger] insertItemWithItemData:model2];
          
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
  
}

- (void)testTrackMethod {
    // 测试主动埋点是否成功
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NSInteger count =  [[ZYTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] track:@"testTrack" values:@{@"event":@"testTrack"}];
    NSArray *all  = [[ZYTrackerEventDBTool sharedManger] getAllDatas];
    FTRecordModel *model =  [all lastObject];
    NSDictionary *item = [ZYBaseInfoHander dictionaryWithJsonString:model.data];
    NSDictionary *op = item[@"opdata"];
    XCTAssertTrue([op[@"field"] isEqualToString:@"testTrack"] && [op[@"values"] isEqual:@{@"event":@"testTrack"}]);
    NSInteger newCount =  [[ZYTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount-count==1);

}
- (void)testLocation{
    //测试是否能够获取地理位置
    FTLocationManager *location = [[FTLocationManager alloc]init];
    location.updateLocationBlock = ^(NSString * _Nonnull location, NSError * _Nonnull error) {
        XCTAssertTrue(location.length>0);

    };
}

- (void)testTags{
    // 测试 FTMonitorInfoType 是否按类型抓取
    dispatch_queue_t queue = dispatch_queue_create("net.test.testQueue", DISPATCH_QUEUE_SERIAL);
       __block NSString *tag;
      FTUploadTool *tool = [[FTUploadTool alloc]initWithConfig:self.config];

       dispatch_async(queue, ^{
           [NSThread sleepForTimeInterval:1.0f];
             tag= [tool performSelector:@selector(getBasicData)];
    if(self.config.monitorInfoType & FTMonitorInfoTypeLocation || self.config.monitorInfoType & FTMonitorInfoTypeAll){
        XCTAssertTrue([tag rangeOfString:@"location_city"].location != NSNotFound);
    }
    if(self.config.monitorInfoType & FTMonitorInfoTypeCamera || self.config.monitorInfoType & FTMonitorInfoTypeAll){
         XCTAssertTrue([tag rangeOfString:@"camera_front_px"].location != NSNotFound);
     }
    if(self.config.monitorInfoType & FTMonitorInfoTypeNetwork || self.config.monitorInfoType & FTMonitorInfoTypeAll){
        XCTAssertTrue([tag rangeOfString:@"network_type"].location != NSNotFound);
    }
    if(self.config.monitorInfoType & FTMonitorInfoTypeCpu || self.config.monitorInfoType & FTMonitorInfoTypeAll){
        XCTAssertTrue([tag rangeOfString:@"cpu_no"].location != NSNotFound);
    }
    if(self.config.monitorInfoType & FTMonitorInfoTypeMemory || self.config.monitorInfoType & FTMonitorInfoTypeAll){
              XCTAssertTrue([tag rangeOfString:@"memory_total"].location != NSNotFound);
      }
    if(self.config.monitorInfoType & FTMonitorInfoTypeBattery || self.config.monitorInfoType & FTMonitorInfoTypeAll){
            XCTAssertTrue([tag rangeOfString:@"battery_use"].location != NSNotFound);
    }
           
  });
}
- (void)testBindUser{

    NSInteger count =  [[ZYTrackerEventDBTool sharedManger] getDatasCount];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
    [NSThread sleepForTimeInterval:10.0];

    [[FTMobileAgent sharedInstance] track:@"testTrack" values:@{@"event":@"testTrack"}];

   [NSThread sleepForTimeInterval:2.0];
    NSInteger newCount =  [[ZYTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount<count);
}
-(void)testChangeUser{
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindUser" Id:@"bindUserId" exts:nil];
   NSArray *array = [[ZYTrackerEventDBTool sharedManger] getFirstTenData];
    NSString *lastUserData;
    if (array.count>0) {
        FTRecordModel *model = [array lastObject];
        lastUserData = model.userdata;
    }
    
    [[FTMobileAgent sharedInstance] logout];
    [[FTMobileAgent sharedInstance] bindUserWithName:@"bindNewUser" Id:@"bindNewUserId" exts:nil];

    [[FTMobileAgent sharedInstance] track:@"testTrack" values:@{@"event":@"testTrack"}];
    [[FTMobileAgent sharedInstance] track:@"testTrack" values:@{@"event":@"testTrack"}];

    NSArray *newarray = [[ZYTrackerEventDBTool sharedManger] getFirstTenData];
    NSString *newUserData;
    if (array.count>0) {
        FTRecordModel *model = [newarray lastObject];
        newUserData = model.userdata;
    }
    XCTAssertTrue(newUserData.length>0 && lastUserData.length>0 && ![newUserData isEqualToString:lastUserData]);

}
@end
