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
#import <FTMobileAgent/FTConstants.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
@interface FTNetworkTests : XCTestCase
@property (nonatomic, strong) FTUploadTool *upTool;
@end

@implementation FTNetworkTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
       long  tm =[[NSDate now] ft_dateTimestamp];
       [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:tm];
       for (int i=0; i<25; i++) {
           NSDictionary *dict = @{
               FT_AGENT_MEASUREMENT:@"iOSTest",
               FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
               FT_AGENT_TAGS:@{@"name":[NSString stringWithFormat:@"FTNetworkTests%d",i]},
           };
           NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                                 FT_AGENT_OPDATA:dict,
           };
          
           FTRecordModel *model = [FTRecordModel new];
           model.op =FTNetworkingTypeMetrics;
           model.data =[FTBaseInfoHander ft_convertToJsonData:data];
           [[FTTrackerEventDBTool sharedManger] insertItemWithItemData:model];
       }
       NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
       NSLog(@"Record Count == %ld",(long)count);
}
- (void)setRightConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"TACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"TACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"TACCESS_SERVER_URL"];
    NSString *token = [processInfo environment][@"TACCESS_DATAWAY_TOKEN"];
    if (akId && akSecret && url) {
     FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
      config.enableLog = YES;
      self.upTool = [[FTUploadTool alloc]initWithConfig:config];
        [NSThread sleepForTimeInterval:2];
    }
}
-(void)setBadMetricsUrl{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"TACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"TACCESS_KEY_SECRET"];
    NSString *token = [processInfo environment][@"TACCESS_DATAWAY_TOKEN"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"https://www.baidu.com" datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
    
    
    config.enableLog = YES;
    config.enableAutoTrack = YES;
    self.upTool = [[FTUploadTool alloc]initWithConfig:config];
}
- (void)setOHHTTPStubs{
    [self setRightConfig];
    [NSThread sleepForTimeInterval:2];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TACCESS_SERVER_URL"];

    NSURL *url = [NSURL URLWithString:urlStr];
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
     NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TACCESS_SERVER_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];

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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TACCESS_SERVER_URL"];

    NSURL *url = [NSURL URLWithString:urlStr];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
    }];
    
}
-(void)setErrorResponseOHHTTPStubs{
    [self setRightConfig];
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TACCESS_SERVER_URL"];

    NSURL *url = [NSURL URLWithString:urlStr];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TACCESS_SERVER_URL"];

    NSURL *url = [NSURL URLWithString:urlStr];
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
     NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TACCESS_SERVER_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
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
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TACCESS_SERVER_URL"];

    NSURL *url = [NSURL URLWithString:urlStr];
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
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    [self.upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        NSError *errors;
        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&errors];
        NSString *result =[[ NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        XCTAssertTrue(response == nil && [result isEqualToString:@"Hello World!"]);
    }];
}
/**
测试请求成功 返回结果为错误json数据格式
*/
- (void)testWrongJsonResponseNetWork{
    [self setWrongJsonResponseOHHTTPStubs];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    [self.upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        NSError *errors;
        NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:&errors];
        XCTAssertTrue(errors != nil);
    }];
}
/**
  测试请求成功 返回结果为空数据
*/
- (void)testEmptyResponseDataNetWork{
    [self setEmptyResponseOHHTTPStubs];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    [self.upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(response == nil);
    }];
}
/**
  测试请求成功 返回结果code 非200
*/
- (void)testErrorResponse{
    [self setErrorResponseOHHTTPStubs];
     NSDictionary *dict = @{
           FT_AGENT_MEASUREMENT:@"iOSTest",
           FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
           FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
       };
       NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                             FT_AGENT_OPDATA:dict,
       };
       
       FTRecordModel *model = [FTRecordModel new];
       model.op =FTNetworkingTypeMetrics;
       model.data =[FTBaseInfoHander ft_convertToJsonData:data];
       [self.upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
           XCTAssertTrue(response == nil);
       }];
}
/**
 测试无效地址
 */
-(void)testBadMetricsUrl{
    [self setBadMetricsUrl];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    [self.upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(statusCode != 200);
    }];
}
/**
 测试网络错误
 */
- (void)testErrorNet{
    [self setErrorNetOHHTTPStubs];
    NSDictionary *dict = @{
        FT_AGENT_MEASUREMENT:@"iOSTest",
        FT_AGENT_FIELD:@{@"event":@"FTNetworkTests"},
        FT_AGENT_TAGS:@{@"name":@"FTNetworkTests"},
    };
    NSDictionary *data =@{FT_AGENT_OP:FTNetworkingTypeMetrics,
                          FT_AGENT_OPDATA:dict,
    };
    
    FTRecordModel *model = [FTRecordModel new];
    model.op =FTNetworkingTypeMetrics;
    model.data =[FTBaseInfoHander ft_convertToJsonData:data];
    [self.upTool trackImmediate:model callBack:^(NSInteger statusCode, NSData * _Nullable response) {
        XCTAssertTrue(response == nil && statusCode == -1009);
    }];
}
@end
