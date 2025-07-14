//
//  FTNetworkMock.m
//  Examples
//
//  Created by hulilei on 2024/5/16.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "FTNetworkMock.h"
#import "FTJSONUtil.h"
typedef void (^CompletionHandler)(void);

static NSString *urlStr;
@implementation FTNetworkMock
+ (void)registerUrlString:(NSString *)urlString{
    urlStr = urlString;
}

+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubs{
    return [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        if(urlStr&&urlStr.length>0){
            return [request.URL.absoluteString isEqualToString:urlStr];
        }
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubsHandler:(void (^)(void))handler{
    id<OHHTTPStubsDescriptor> stubs = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        if(urlStr&&urlStr.length>0){
            return [request.URL.absoluteString isEqualToString:urlStr];
        }
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
            if(handler){
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    handler();
                });
        }
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
    return stubs;
}
@end
