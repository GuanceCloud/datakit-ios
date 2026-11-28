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

#import "FTDiagnosticsBridge.h"
#import "FTHTTPClient.h"
#import "FTInternalConstants.h"
#import <objc/runtime.h>
static char FTDiagnosticMetricsKey;
// A dedicated delegate has no reference to FTHTTPClient, avoiding a session retain cycle.
@interface FTDiagnosticUploadDelegate : NSObject <NSURLSessionTaskDelegate>
@end
@implementation FTDiagnosticUploadDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    if (![FTDiagnosticsBridge enabled]) return;
    int64_t tx=0,rx=0; BOOL valid=metrics.transactionMetrics.count>0;
    for (NSURLSessionTaskTransactionMetrics *m in metrics.transactionMetrics) {
        if(m.countOfRequestBodyBytesSent<0 || m.countOfResponseBodyBytesReceived<0){valid=NO;break;}
        tx+=m.countOfRequestBodyBytesSent;rx+=m.countOfResponseBodyBytesReceived;
    }
    if(valid)objc_setAssociatedObject(task,&FTDiagnosticMetricsKey,@[@(tx),@(rx)],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end


NSErrorDomain const FTHTTPClientErrorDomain = @"com.ft.sdk.httpclient";

@interface FTHTTPClient()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) BOOL cancelled;
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
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:[FTDiagnosticUploadDelegate new] delegateQueue:nil];
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
    FTDiagnosticsAttempt *attempt = [FTDiagnosticsBridge begin:NSStringFromClass([request class]) payloadBytes:-1];
    __block __weak NSURLSessionDataTask *observedTask;
    NSURLSessionDataTask  *task =
    
    [self.session dataTaskWithRequest:urlRequest
                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (attempt) {
            NSArray *bytes=objc_getAssociatedObject(observedTask,&FTDiagnosticMetricsKey);
            [attempt finishWithStatus:httpResponse ? httpResponse.statusCode : -1
                       transportError:error != nil
                         requestBytes:bytes ? [bytes[0] longLongValue] : -1
                        responseBytes:bytes ? [bytes[1] longLongValue] : -1
                               source:@"NSURLSessionTaskMetrics_encoded_body; excludes_headers_tls_tcp"];
        }
        if (!callback) {
            return;
        }
        callback(httpResponse,data,error);
       
    }];
    
    observedTask = task;
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
    @synchronized (self) {
    if (self.cancelled) {
        if (callback) callback(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
        return;
    }
    NSURLSessionDataTask *task = [self realSendRequest:request completion:callback];
    if(!task && callback){
        NSError *error = [NSError errorWithDomain:FTHTTPClientErrorDomain
                                             code:FTHTTPClientErrorCodeRequestCreationFailed
                                         userInfo:@{NSLocalizedDescriptionKey:@"Failed to create upload request"}];
        callback(nil,nil,error);
    }
    }
}
- (void)cancel {
    @synchronized (self) {
        self.cancelled = YES;
        [self.session invalidateAndCancel];
    }
}
-(void)dealloc{
    [self.session finishTasksAndInvalidate];
}
@end
