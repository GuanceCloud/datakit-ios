//
//  FTHTTPClient.m
//  FTSDK
//
//  Created by hulilei on 2021/8/2.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTHTTPClient.h"
#import "FTInternalConstants.h"

NSErrorDomain const FTHTTPClientErrorDomain = @"com.ft.sdk.httpclient";

@interface FTHTTPClient()
@property (nonatomic, strong) NSURLSession *session;
@end
@implementation FTHTTPClient
-(instancetype)init{
    return [self initWithTimeoutIntervalForRequest:30];
}
-(instancetype)initWithTimeoutIntervalForRequest:(NSTimeInterval)timeOut{
    self = [super init];
    if(self){
        NSURLSessionConfiguration  *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = timeOut;
        configuration.HTTPShouldUsePipelining = NO;
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}
- (NSURLSessionDataTask *)realSendRequest:(id<FTRequestProtocol>)request
                           completion:(void(^_Nullable)(NSHTTPURLResponse * _Nullable httpResponse,
                             NSData * _Nullable data,
                             NSError * _Nullable error))callback{
    
    NSURLRequest *urlRequest = [self createRequest:request];
    if(!urlRequest){
        return nil;
    }
    NSURLSessionDataTask  *task =
    
    [self.session dataTaskWithRequest:urlRequest
                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (!callback) {
            return;
        }
        callback(httpResponse,data,error);
       
    }];
    
    [task resume];
    
    return task;
}
- (NSURLRequest *)createRequest:(id<FTRequestProtocol>)requestObject{
    NSURL *url = requestObject.absoluteURL;
    if (!url) {
        return nil;
    }
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:url];
    [urlRequest setValue:@"true" forHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST];
    if([requestObject respondsToSelector:@selector(adaptedRequest:)]){
        urlRequest = [requestObject adaptedRequest:urlRequest];
    }
    return urlRequest;
}

- (void)sendRequest:(id<FTRequestProtocol>  _Nonnull)request
         completion:(void(^_Nullable)(NSHTTPURLResponse * _Nullable httpResponse,
                                      NSData * _Nullable data,
                                      NSError * _Nullable error))callback{
    NSURLSessionDataTask *task = [self realSendRequest:request completion:callback];
    if(!task && callback){
        NSError *error = [NSError errorWithDomain:FTHTTPClientErrorDomain
                                             code:FTHTTPClientErrorCodeRequestCreationFailed
                                         userInfo:@{NSLocalizedDescriptionKey:@"Failed to create upload request"}];
        callback(nil,nil,error);
    }
}
-(void)dealloc{
    [self.session finishTasksAndInvalidate];
}
@end
