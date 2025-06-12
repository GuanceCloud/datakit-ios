//
//  FTURLSessionDelegate.m
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


#import "FTURLSessionDelegate+Private.h"
#import "FTURLSessionInstrumentation.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "NSURLSession+FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTTraceContext.h"
#import "NSURLSessionTask+FTSwizzler.h"

@interface FTURLSessionDelegate()<FTURLSessionInterceptorProtocol>
@property (nonatomic,strong,readwrite) FTURLSessionInstrumentation *instrumentation;
@end
@implementation FTURLSessionDelegate
@synthesize ftURLSessionDelegate;
-(FTURLSessionDelegate *)ftURLSessionDelegate{
    return self;
}
- (FTURLSessionInstrumentation *)instrumentation{
    return [FTURLSessionInstrumentation sharedInstance];
}
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request{
    NSURLRequest *interceptedRequest = request;
    if(self.requestInterceptor){
        interceptedRequest = self.requestInterceptor(request);
        return interceptedRequest;
    }
    if(self.traceInterceptor){
        FTTraceContext *context = self.traceInterceptor(request);
        NSMutableURLRequest *mutableRequest = [interceptedRequest mutableCopy];
        if (context.traceHeader && context.traceHeader.allKeys.count>0) {
            [context.traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
                [mutableRequest setValue:value forHTTPHeaderField:field];
            }];
        }
        return mutableRequest;
    }
    return [self.instrumentation.interceptor interceptRequest:interceptedRequest];
}
- (void)traceInterceptTask:(NSURLSessionTask *)task{
    if(self.requestInterceptor){
       NSURLRequest *interceptedRequest = self.requestInterceptor(task.currentRequest);
        if(interceptedRequest){
            [task setValue:interceptedRequest forKey:@"currentRequest"];
        }
       return;
    }
    [self.instrumentation.interceptor traceInterceptTask:task traceInterceptor:self.traceInterceptor];
}
- (void)interceptTask:(NSURLSessionTask *)task{
    [self.instrumentation.interceptor interceptTask:task];
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.instrumentation.interceptor taskReceivedData:dataTask data:data];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    // custom = YES 主要是为了优先处理 URLSession 级自定义的 provider
    [self.instrumentation.interceptor taskMetricsCollected:task metrics:metrics custom:YES];
    if (@available(iOS 15.0,tvOS 15.0,macOS 12.0, *)) {
        if(!task.ft_hasCompletion){
            [self dealTaskCompleted:task error:task.error];
        }
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [self dealTaskCompleted:task error:error];
}
-(void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data{
    [self.instrumentation.interceptor taskReceivedData:task data:data];
}
-(void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    [self dealTaskCompleted:task error:error];
}
-(void)dealTaskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    [self.instrumentation.interceptor taskCompleted:task error:error extraProvider:self.provider errorFilter:self.errorFilter];
}
@end
