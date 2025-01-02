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
#import "NSURLSessionTask+FTSwizzler.h"
#import "FTURLSessionInstrumentation.h"
#import "FTURLSessionDelegate+Private.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTDURLSessionDelegate.h"
#import "FTSwizzle.h"
#import "FTSwizzler.h"
#import "FTLog+Private.h"
#import <objc/runtime.h>
typedef void (^CompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@implementation NSURLSession (FTSwizzler)
+(void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = NULL;
        [NSURLSession ft_swizzleClassMethod:@selector(ft_sessionWithConfiguration:delegate:delegateQueue:) withClassMethod:@selector(sessionWithConfiguration:delegate:delegateQueue:) error:&error];
        if(@available(iOS 13.0,macOS 10.15,*)){
            [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithURL:completionHandler:) withMethod:@selector(dataTaskWithURL:completionHandler:) error:&error];
        }
        [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithRequest:completionHandler:) withMethod:@selector(dataTaskWithRequest:completionHandler:) error:&error];
        Class taskClass = NSClassFromString(@"__NSCFLocalSessionTask");
        if(taskClass){
            NSError *error = NULL;
            [taskClass ft_swizzleMethod:@selector(resume) withMethod:@selector(ft_resume) error:&error];
        }
    });
}
- (NSURLSessionDataTask *)ft_dataTaskWithURL:(NSURL *)url completionHandler:(CompletionHandler)completionHandler{
    id<FTURLSessionInterceptorProtocol> rumIntercepter = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:self.delegate];
    if (rumIntercepter){
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
                task.ft_hasCompletion = YES;
                taskReference = task;
            }else{
                task = [self ft_dataTaskWithURL:url completionHandler:completionHandler];
            }
            return task;
        }
    }
    return [self ft_dataTaskWithURL:url completionHandler:completionHandler];
}
- (NSURLSessionDataTask *)ft_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(CompletionHandler)completionHandler{
    @try {
        id<FTURLSessionInterceptorProtocol> rumIntercepter = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:self.delegate];
        if (rumIntercepter){
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
                    task = [self ft_dataTaskWithRequest:request completionHandler:newCompletionHandler];
                    task.ft_hasCompletion = YES;
                    taskReference = task;
                }else{
                    task = [self ft_dataTaskWithRequest:request completionHandler:completionHandler];
                }
                return task;
            }
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }
    return [self ft_dataTaskWithRequest:request completionHandler:completionHandler];
}
+(NSURLSession *)ft_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id<NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue{
    id<NSURLSessionDelegate> realDelegate = delegate;
    @try {
        if (delegate == nil) {
            realDelegate = [[FTDURLSessionDelegate alloc]init];
        }else if(![realDelegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
            [[FTURLSessionInstrumentation sharedInstance] enableSessionDelegate:realDelegate];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }
    return [NSURLSession ft_sessionWithConfiguration:configuration delegate:realDelegate delegateQueue:queue];
}
@end
