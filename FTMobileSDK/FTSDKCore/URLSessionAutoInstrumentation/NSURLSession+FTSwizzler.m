//
//  NSURLSession+FTSwizzler.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/9/13.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#import "NSURLSession+FTSwizzler.h"
#import "FTURLSessionInstrumentation.h"
#import "FTURLSessionDelegate.h"
#import "FTURLSessionInterceptor.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTURLSessionDelegate+Private.h"
typedef void (^CompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
@implementation NSURLSession (FTSwizzler)
- (NSURLSessionDataTask *)ft_dataTaskWithURL:(NSURL *)url{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:url]){
            id <FTURLSessionDelegateProviding> realDelegate = (id <FTURLSessionDelegateProviding>) self.delegate;
            FTURLSessionDelegate *sessionDelegate = realDelegate.ftURLSessionDelegate;
            NSURLSessionDataTask *task = [self ft_dataTaskWithURL:url];
            if (@available(iOS 13.0, *)) {
                NSURLRequest *interceptedRequest = [sessionDelegate interceptRequest:task.originalRequest];
                [task setValue:interceptedRequest forKey:@"currentRequest"];
                [sessionDelegate interceptTask:task];
            }
            return task;
        }
    }
    return [self ft_dataTaskWithURL:url];
}
- (NSURLSessionDataTask *)ft_dataTaskWithURL:(NSURL *)url completionHandler:(CompletionHandler)completionHandler{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:url]){
            id <FTURLSessionDelegateProviding> realDelegate = (id <FTURLSessionDelegateProviding>) self.delegate;
            FTURLSessionDelegate *sessionDelegate = realDelegate.ftURLSessionDelegate;
            NSURLSessionDataTask *task;
            if (completionHandler) {
                __block NSURLSessionDataTask *taskReference;
                CompletionHandler newCompletionHandler = ^(NSData * data, NSURLResponse * response, NSError * error){
                    completionHandler(data,response,error);
                    if (taskReference){
                        if (data) {
                            [sessionDelegate URLSession:self dataTask:taskReference didReceiveData:data];
                        }
                        [sessionDelegate URLSession:self task:taskReference didCompleteWithError:error];
                    }
                };
                task = [self ft_dataTaskWithURL:url completionHandler:newCompletionHandler];
                taskReference = task;
            }else{
                task = [self ft_dataTaskWithURL:url completionHandler:completionHandler];
            }
            NSURLRequest *interceptedRequest = [sessionDelegate interceptRequest:task.originalRequest];
            [task setValue:interceptedRequest forKey:@"currentRequest"];
            [sessionDelegate interceptTask:task];
            return task;
        }
    }
    return [self ft_dataTaskWithURL:url completionHandler:completionHandler];
}
- (NSURLSessionDataTask *)ft_dataTaskWithRequest:(NSURLRequest *)request{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:request.URL]){
            id <FTURLSessionDelegateProviding> realDelegate = (id <FTURLSessionDelegateProviding>) self.delegate;
            FTURLSessionDelegate *sessionDelegate = realDelegate.ftURLSessionDelegate;
            NSURLRequest *newRequest = [sessionDelegate interceptRequest:request];
            NSURLSessionDataTask *task = [self ft_dataTaskWithRequest:newRequest];
            if (@available(iOS 13.0, *)) {
                [sessionDelegate interceptTask:task];
            }
            return task;
        }
    }
    return [self ft_dataTaskWithRequest:request];
}
- (NSURLSessionDataTask *)ft_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(CompletionHandler)completionHandler{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:request.URL]){
            id <FTURLSessionDelegateProviding> realDelegate = (id <FTURLSessionDelegateProviding>) self.delegate;
            FTURLSessionDelegate *sessionDelegate = realDelegate.ftURLSessionDelegate;
            NSURLSessionDataTask *task;
            if (completionHandler) {
                __block NSURLSessionDataTask *taskReference;
                CompletionHandler newCompletionHandler = ^(NSData * data, NSURLResponse * response, NSError * error){
                    completionHandler(data,response,error);
                    if (taskReference){
                        if (data) {
                            [sessionDelegate URLSession:self dataTask:taskReference didReceiveData:data];
                        }
                        [sessionDelegate URLSession:self task:taskReference didCompleteWithError:error];
                    }
                };
                NSURLRequest *newRequest = [sessionDelegate interceptRequest:request];
                task = [self ft_dataTaskWithRequest:newRequest completionHandler:newCompletionHandler];
                taskReference = task;
            }else{
                task = [self ft_dataTaskWithRequest:request completionHandler:completionHandler];
            }
            [sessionDelegate interceptTask:task];
            return task;
        }
    }
    return [self ft_dataTaskWithRequest:request completionHandler:completionHandler];
}
+(NSURLSession *)ft_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id<NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue{
    FTURLSessionDelegate *ftDelegate = [[FTURLSessionDelegate alloc] initWithRealDelegate:delegate];
    return [NSURLSession ft_sessionWithConfiguration:configuration delegate:ftDelegate delegateQueue:queue];
}
@end
