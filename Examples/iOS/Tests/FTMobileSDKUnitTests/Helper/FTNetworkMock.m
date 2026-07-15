//
//  FTNetworkMock.m
//  Examples
//
//  Created by hulilei on 2024/5/16.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTNetworkMock.h"
#import "FTJSONUtil.h"
typedef void (^CompletionHandler)(void);

@implementation FTNetworkMock

+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubs{
    return [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
}
+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubsHandler:(void (^)(void))handler{
    return [self networkOHHTTPStubsWithUrl:nil handler:handler];
}
+ (id<OHHTTPStubsDescriptor>)networkOHHTTPStubsWithUrl:(nullable NSString *)urlStr handler:(nullable void (^)(void))handler{
    NSObject *handlerGuard = [NSObject new];
    __block BOOL didScheduleHandler = NO;
    id<OHHTTPStubsDescriptor> stubs = [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        if(urlStr&&urlStr.length>0){
            return [request.URL.absoluteString isEqualToString:urlStr];
        }
        return YES;
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSString *data  =[FTJSONUtil convertToJsonData:@{@"data":@"Hello World!",@"code":@200}];
        NSData *requestData = [data dataUsingEncoding:NSUTF8StringEncoding];
        if(handler){
            BOOL shouldScheduleHandler = NO;
            @synchronized (handlerGuard) {
                if (!didScheduleHandler) {
                    didScheduleHandler = YES;
                    shouldScheduleHandler = YES;
                }
            }
            if (shouldScheduleHandler) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    handler();
                });
            }
        }
        return [OHHTTPStubsResponse responseWithData:requestData statusCode:200 headers:nil];
    }];
    return stubs;
}
@end
