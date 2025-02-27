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
static CompletionHandler g_handler;

static NSString *urlStr;
@implementation FTNetworkMock
+ (void)registerUrlString:(NSString *)urlString{
    urlStr = urlString;
}
+ (void)registerHandler:(void (^)(void))handler{
    g_handler = handler;
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
+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubsHandler{
    return [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        if(urlStr&&urlStr.length>0){
            return [request.URL.absoluteString isEqualToString:urlStr];
        }
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        if(g_handler){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if(g_handler){
                    g_handler();
                    g_handler = nil;
                }
            });
        }
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
@end
