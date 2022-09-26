//
//  URLSessionAutoInstrumentation.m
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


#import "URLSessionAutoInstrumentation.h"
#import "NSURLSession+FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTURLSessionInterceptor.h"
#include "FTURLProtocol.h"
#import "FTMobileConfig.h"
@interface URLSessionAutoInstrumentation()<URLSessionInterceptorType>
@property (nonatomic, assign) BOOL swizzle;
@property (nonatomic, assign) BOOL enableRumTrack;
@end
@implementation URLSessionAutoInstrumentation
- (instancetype)init{
    return [self initWithInterceptor:[FTURLSessionInterceptor sharedInstance]];
}
- (instancetype)initWithInterceptor:(id <URLSessionInterceptorType>)interceptor{
    self = [super init];
    if (self) {
        _interceptor = interceptor;
    }
    return self;
}
-(id<URLSessionInterceptorType>)interceptor{
    return _interceptor;
}
-(void)setSdkUrlStr:(NSString *)sdkUrlStr{
    _sdkUrlStr = sdkUrlStr;
    _interceptor.innerUrl = sdkUrlStr;
}
-(id<FTRumResourceProtocol>)rumResourceHandler{
    return [FTURLSessionInterceptor sharedInstance];
}
- (void)setRUMConfig:(FTRumConfig *)config{
    self.enableRumTrack = config.enableTraceUserResource;
    [self startMonitor];
}
- (void)setTraceConfig:(FTTraceConfig *)config tracer:(nonnull id<FTTracerProtocol>)tracer{
    [[FTURLSessionInterceptor sharedInstance] enableAutoTrace:config.enableAutoTrace];
    [[FTURLSessionInterceptor sharedInstance] enableLinkRumData:config.enableLinkRumData];
    [[FTURLSessionInterceptor sharedInstance] setTracer:tracer];
    [FTURLProtocol setDelegate:self];
    [self startMonitor];
}
- (void)startMonitor{
    if (self.swizzle) {
        return;
    }
    self.swizzle = YES;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = NULL;
        if (@available(iOS 13.0, *)) {
            [NSURLSession ft_swizzleMethod:@selector(dataTaskWithURL:) withMethod:@selector(ft_dataTaskWithURL:) error:&error];
            [NSURLSession ft_swizzleMethod:@selector(dataTaskWithRequest:) withMethod:@selector(ft_dataTaskWithRequest:) error:&error];
        }
        [NSURLSession ft_swizzleMethod:@selector(dataTaskWithURL:completionHandler:) withMethod:@selector(ft_dataTaskWithURL:completionHandler:) error:&error];
        [NSURLSession ft_swizzleMethod:@selector(dataTaskWithRequest:completionHandler:) withMethod:@selector(ft_dataTaskWithRequest:completionHandler:) error:&error];
    });
    [FTURLProtocol startMonitor];
    [FTURLProtocol setDelegate:self];
}
#pragma mark --------- URLSessionInterceptorType ----------
// 处理 URLProtocol 获取的 resource 数据
-(NSURLRequest *)injectTraceHeader:(NSURLRequest *)request{
    return [[FTURLSessionInterceptor sharedInstance] injectTraceHeader:request];
}
-(void)taskCreated:(NSURLSessionTask *)task session:(NSURLSession *)session{
    if(self.enableRumTrack){
        [[FTURLSessionInterceptor sharedInstance] taskCreated:task session:session];
    }
}
-(void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data{
    if(self.enableRumTrack){
        [[FTURLSessionInterceptor sharedInstance] taskReceivedData:task data:data];
    }
}
-(void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    if(self.enableRumTrack){
        [[FTURLSessionInterceptor sharedInstance] taskCompleted:task error:error];
    }
}
-(void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics{
    if(self.enableRumTrack){
        [[FTURLSessionInterceptor sharedInstance] taskMetricsCollected:task metrics:metrics];
    }
}
@end
