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
#import "FTURLSessionDelegate+Private.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTURLSessionDelegate+Private.h"
#import "FTSwizzle.h"
#import "FTSwizzler.h"
#import <objc/runtime.h>
typedef void (^CompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
@implementation NSURLSession (FTSwizzler)
+(void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = NULL;
        [NSURLSession ft_swizzleClassMethod:@selector(ft_sessionWithConfiguration:delegate:delegateQueue:) withClassMethod:@selector(sessionWithConfiguration:delegate:delegateQueue:) error:&error];
    });
}
- (NSURLSessionDataTask *)ft_dataTaskWithURL:(NSURL *)url{
    id<FTURLSessionInterceptorProtocol> traceIntercepter = [self traceInterceptor];
    id<FTURLSessionInterceptorProtocol> rumIntercepter = [self rumInterceptor];
    if (traceIntercepter || rumIntercepter){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:url]){
            NSURLSessionDataTask *task = [self ft_dataTaskWithURL:url];
            if (@available(iOS 13.0, *)) {
                if(traceIntercepter){
                    NSURLRequest *interceptedRequest = [traceIntercepter interceptRequest:task.originalRequest];
                    [task setValue:interceptedRequest forKey:@"currentRequest"];
                }
                [rumIntercepter interceptTask:task];
            }
            return task;
        }
    }
    return [self ft_dataTaskWithURL:url];
}
- (NSURLSessionDataTask *)ft_dataTaskWithURL:(NSURL *)url completionHandler:(CompletionHandler)completionHandler{
    id<FTURLSessionInterceptorProtocol> traceIntercepter = [self traceInterceptor];
    id<FTURLSessionInterceptorProtocol> rumIntercepter = [self rumInterceptor];
    if (traceIntercepter || rumIntercepter){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:url]){
            NSURLSessionDataTask *task;
            if (completionHandler) {
                __block NSURLSessionDataTask *taskReference;
                CompletionHandler newCompletionHandler = ^(NSData * data, NSURLResponse * response, NSError * error){
                    completionHandler(data,response,error);
                    if (taskReference){
                        if (data) {
                            [rumIntercepter taskReceivedData:taskReference data:data];
                        }
                        [rumIntercepter taskCompleted:taskReference error:error];
                    }
                };
                task = [self ft_dataTaskWithURL:url completionHandler:newCompletionHandler];
                taskReference = task;
            }else{
                task = [self ft_dataTaskWithURL:url completionHandler:completionHandler];
            }
            if(traceIntercepter){
                NSURLRequest *interceptedRequest = [traceIntercepter interceptRequest:task.originalRequest];
                [task setValue:interceptedRequest forKey:@"currentRequest"];
            }
            [rumIntercepter interceptTask:task];
            return task;
        }
    }
    return [self ft_dataTaskWithURL:url completionHandler:completionHandler];
}
- (NSURLSessionDataTask *)ft_dataTaskWithRequest:(NSURLRequest *)request{
    id<FTURLSessionInterceptorProtocol> traceIntercepter = [self traceInterceptor];
    id<FTURLSessionInterceptorProtocol> rumIntercepter = [self rumInterceptor];
    if (traceIntercepter  || rumIntercepter){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:request.URL]){
            NSURLRequest *newRequest = traceIntercepter? [traceIntercepter interceptRequest:request]:request;
            NSURLSessionDataTask *task = [self ft_dataTaskWithRequest:newRequest];
            if (@available(iOS 13.0, *)) {
                [rumIntercepter interceptTask:task];
            }
            return task;
        }
    }
    return [self ft_dataTaskWithRequest:request];
}
- (NSURLSessionDataTask *)ft_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(CompletionHandler)completionHandler{
    id<FTURLSessionInterceptorProtocol> traceIntercepter = [self traceInterceptor];
    id<FTURLSessionInterceptorProtocol> rumIntercepter = [self rumInterceptor];
    if (traceIntercepter || rumIntercepter){
        if([[FTURLSessionInstrumentation sharedInstance] isNotSDKInsideUrl:request.URL]){
            NSURLSessionDataTask *task;
            if (completionHandler) {
                __block NSURLSessionDataTask *taskReference;
                CompletionHandler newCompletionHandler = ^(NSData * data, NSURLResponse * response, NSError * error){
                    completionHandler(data,response,error);
                    if (taskReference){
                        if (data) {
                            [rumIntercepter taskReceivedData:taskReference data:data];
                        }
                        [rumIntercepter taskCompleted:taskReference error:error];
                    }
                };
                NSURLRequest *newRequest = traceIntercepter?[traceIntercepter interceptRequest:request]:request;
                task = [self ft_dataTaskWithRequest:newRequest completionHandler:newCompletionHandler];
                taskReference = task;
            }else{
                task = [self ft_dataTaskWithRequest:request completionHandler:completionHandler];
            }
            [rumIntercepter interceptTask:task];
            return task;
        }
    }
    return [self ft_dataTaskWithRequest:request completionHandler:completionHandler];
}
- (id<FTURLSessionInterceptorProtocol>)traceInterceptor{
    if([self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        return ((id<FTURLSessionDelegateProviding>)self.delegate).ftURLSessionDelegate;
    }else if([FTURLSessionInstrumentation sharedInstance].shouldTraceInterceptor){
        return [FTURLSessionInstrumentation sharedInstance].interceptor;
    }
    return nil;
}
- (id<FTURLSessionInterceptorProtocol>)rumInterceptor{
    if([self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        return ((id<FTURLSessionDelegateProviding>)self.delegate).ftURLSessionDelegate;
    }else if([FTURLSessionInstrumentation sharedInstance].shouldRUMInterceptor){
        return [FTURLSessionInstrumentation sharedInstance].interceptor;
    }
    return nil;
}
+(NSURLSession *)ft_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id<NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue{
    id<NSURLSessionDelegate> realDelegate = delegate;
    if (delegate == nil) {
        realDelegate = [FTURLSessionInstrumentation sharedInstance];
    }else if(![delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        [[FTURLSessionInstrumentation sharedInstance] enableSessionDelegate:delegate];
    }
    return [NSURLSession ft_sessionWithConfiguration:configuration delegate:realDelegate delegateQueue:queue];
}
@end
