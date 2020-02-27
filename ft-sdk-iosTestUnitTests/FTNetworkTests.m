//
//  FTNetworkTests.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2019/12/24.
//  Copyright © 2019 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTUploadTool.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>
#import "OHHTTPStubs.h"
#import "TestAccount.h"
@interface FTNetworkTests : XCTestCase
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) TestAccount *testAccount;
@end

@implementation FTNetworkTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
       long  tm =[FTBaseInfoHander ft_getCurrentTimestamp];
       [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
       [[FTMobileAgent sharedInstance] logout];
       for (NSInteger i=0; i<25; i++) {
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
           model.tm = [FTBaseInfoHander ft_getCurrentTimestamp];
           model.data =[FTBaseInfoHander ft_convertToJsonData:data];
           [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
           
           NSDictionary *data2 = @{
               @"cpn":@"Test4ViewController",
               @"op": @"click",
               @"opdata":@{
                       @"vtp": @"UIWindow[7]/UITransitionView[6]/UIDropShadowView[5]/UILayoutContainerView[4]/UINavigationTransitionView[3]/UIViewControllerWrapperView[2]/UIView[1]/UITableView[0]",
               },
               @"rpn":@"UINavigationController",
           };
           FTRecordModel *model2 = [FTRecordModel new];
           model2.tm = [FTBaseInfoHander ft_getCurrentTimestamp];
           model2.data =[FTBaseInfoHander ft_convertToJsonData:data2];
           [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model2];
       }
       NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
       [[FTMobileAgent sharedInstance] bindUserWithName:@"11222" Id:@"000000" exts:nil];
       self.testAccount = [[TestAccount alloc]init];
       NSLog(@"Record Count == %ld",(long)count);
}
- (void)setRightConfig{
   
     FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.testAccount.accessServerUrl akId:self.testAccount.accessKeyID akSecret:self.testAccount.accessKeySecret enableRequestSigning:YES];
      config.enableLog = YES;
      config.enableAutoTrack = YES;
      self.upTool = [[FTUploadTool alloc]initWithConfig:config];
}
-(void)setBadMetricsUrl{
      FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"https://www.baidu.com" akId:self.testAccount.accessKeyID akSecret:self.testAccount.accessKeySecret enableRequestSigning:YES];

      config.enableLog = YES;
      config.enableAutoTrack = YES;
      self.upTool = [[FTUploadTool alloc]initWithConfig:config];
}
- (void)setOHHTTPStubs{
    [self setRightConfig];
    NSURL *url = [NSURL URLWithString:self.testAccount.accessServerUrl];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
      return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        
        NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];

      NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
      return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
-(void)setBadNetOHHTTPStubs{
    [self setRightConfig];
    NSURL *url = [NSURL URLWithString:self.testAccount.accessServerUrl];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];

        NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [[OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil]
                requestTime:1.0 responseTime:3.0];
    }];
}

-(void)setErrorNetOHHTTPStubs{
    [self setRightConfig];
    NSURL *url = [NSURL URLWithString:self.testAccount.accessServerUrl];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
    }];
    
}
-(void)setErrorResponseOHHTTPStubs{
    [self setRightConfig];
    NSURL *url = [NSURL URLWithString:self.testAccount.accessServerUrl];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
      return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        
        NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@500}];

      NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
      return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
-(void)setNoJsonResponseOHHTTPStubs{
    [self setRightConfig];
    NSURL *url = [NSURL URLWithString:self.testAccount.accessServerUrl];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =@"Hello World!";

        NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
-(void)setWrongJsonResponseOHHTTPStubs{
    [self setRightConfig];
    NSURL *url = [NSURL URLWithString:self.testAccount.accessServerUrl];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
           return [request.URL.host isEqualToString:url.host];
       } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
           NSString *data  =[FTBaseInfoHander ft_convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
           data = [data stringByAppendingString:@"/n/t"];
           NSData* requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
           return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
       }];
}
-(void)setEmptyResponseOHHTTPStubs{
     [self setRightConfig];
     NSURL *url = [NSURL URLWithString:self.testAccount.accessServerUrl];

     [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
         return [request.URL.host isEqualToString:url.host];
     } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        
         return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:200 headers:nil];
     }];
}
/**
测试上传过程是否正确
*/
-(void)testNetwork{
     [self setOHHTTPStubs];
     [self.upTool upload];
              
     NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
      //验证数据库中数据是否上传完毕
     XCTAssertTrue(count== 0);
            
}
/**
测试网络状态较差时上传过程是否正确
*/
-(void)testBadNetwork{
    [self setBadNetOHHTTPStubs];
    [self.upTool upload];
                 
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    //验证数据库中数据是否上传完毕
    XCTAssertTrue(count== 0);
}

/**
 测试请求成功 返回结果为非json数据格式
 */
-(void)testNoJsonResponseNetWork{
    [self setNoJsonResponseOHHTTPStubs];
    [self.upTool upload];
    
    
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    //验证数据库中数据 返回请求结果错误时 数据库数据不变
    XCTAssertTrue(count== 50);
}
/**
测试请求成功 返回结果为错误json数据格式
*/
- (void)testWrongJsonResponseNetWork{
    [self setWrongJsonResponseOHHTTPStubs];
    [self.upTool upload];
       
       
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    //验证数据库中数据 返回请求结果错误时 数据库数据不变
    XCTAssertTrue(count== 50);
}
/**
  测试请求成功 返回结果为空数据
*/
- (void)testEmptyResponseDataNetWork{
    [self setEmptyResponseOHHTTPStubs];
    [self.upTool upload];
          
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    //验证数据库中数据 返回请求结果错误时 数据库数据不变
    XCTAssertTrue(count== 50);
}
/**
  测试请求成功 返回结果code 非200
*/
- (void)testErrorResponse{
    [self setErrorResponseOHHTTPStubs];
    [self.upTool upload];
                    
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    //验证数据库中数据 返回请求结果错误时 数据库数据不变
    XCTAssertTrue(count== 50);
}
/**
 测试无效地址
 */
-(void)testBadMetricsUrl{
    [self setBadMetricsUrl];
    [self.upTool upload];
    
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    //上传失败 数据库数据不变
    XCTAssertTrue(count== 50);
}
/**
 测试网络错误
 */
- (void)testErrorNet{
    [self setErrorNetOHHTTPStubs];
    [self.upTool upload];
    
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    //上传失败 数据库数据不变
    XCTAssertTrue(count== 50);
}
@end
