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


#import "FTURLSessionAutoInstrumentation.h"
#import "NSURLSession+FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTURLSessionInterceptor.h"
#include "FTURLProtocol.h"
#import "FTMobileConfig.h"
#import "FTTracer.h"
@interface FTURLSessionAutoInstrumentation()<URLSessionInterceptorType>
@property (nonatomic, assign) BOOL swizzle;
@property (nonatomic, assign) BOOL enableRumTrack;
@property (nonatomic, strong) FTURLSessionInterceptor *sessionInterceptor;
@property (nonatomic, strong) FTTracer *tracer;
@end
@implementation FTURLSessionAutoInstrumentation
static FTURLSessionAutoInstrumentation *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
- (instancetype)init{
    self = [super init];
    if (self) {
        _sessionInterceptor = [FTURLSessionInterceptor new];
    }
    return self;
}
-(id<URLSessionInterceptorType>)interceptor{
    return _sessionInterceptor;
}
-(void)setSdkUrlStr:(NSString *)sdkUrlStr{
    _sdkUrlStr = sdkUrlStr;
    self.interceptor.innerUrl = sdkUrlStr;
}
-(id<FTRumResourceProtocol>)rumResourceHandler{
    return _sessionInterceptor;
}
-(id<FTTracerProtocol>)tracer{
    return _tracer;
}
- (void)setRUMConfig:(FTRumConfig *)config{
    self.enableRumTrack = config.enableTraceUserResource;
    self.interceptor.enableAutoRumTrack = config.enableTraceUserResource;
    [self startMonitor];
}
- (void)setTraceConfig:(FTTraceConfig *)config{
    [_sessionInterceptor enableAutoTrace:config.enableAutoTrace];
    [_sessionInterceptor enableLinkRumData:config.enableLinkRumData];
    _tracer = [[FTTracer alloc]initWithConfig:config];
    if(config.enableAutoTrace){
        [_sessionInterceptor setTracer:_tracer];
        [self startMonitor];
    }
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
    [FTURLProtocol setDelegate:self.interceptor];
}
#pragma mark --------- URLSessionInterceptorType ----------
// 处理 URLProtocol 获取的 resource 数据，由于可能用户设置不自动采集rum resource，但是开启了 enableAutoTrace ，在这里做一个过滤
-(NSURLRequest *)injectTraceHeader:(NSURLRequest *)request{
    return [_sessionInterceptor injectTraceHeader:request];
}
-(void)taskCreated:(NSURLSessionTask *)task session:(NSURLSession *)session{
    if(self.enableRumTrack){
        [_sessionInterceptor taskCreated:task session:session];
    }
}
-(void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data{
    if(self.enableRumTrack){
        [_sessionInterceptor taskReceivedData:task data:data];
    }
}
-(void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error{
    if(self.enableRumTrack){
        [_sessionInterceptor taskCompleted:task error:error];
    }
}
-(void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics{
    if(self.enableRumTrack){
        [_sessionInterceptor taskMetricsCollected:task metrics:metrics];
    }
}
- (void)resetInstance{
    onceToken = 0;
    sharedInstance =nil;
}
@end
