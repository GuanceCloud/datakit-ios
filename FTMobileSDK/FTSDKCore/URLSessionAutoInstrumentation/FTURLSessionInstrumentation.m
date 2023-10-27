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


#import "FTURLSessionInstrumentation.h"
#import "NSURLSession+FTSwizzler.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTURLSessionInterceptor.h"
#import "FTURLProtocol.h"
#import "FTTracer.h"
#import <objc/runtime.h>
@interface FTURLSessionInstrumentation()
/// sdk 内部的数据上传 url
@property (nonatomic, copy) NSString *sdkUrlStr;
@property (nonatomic, assign) BOOL enableAutoTrace;
@property (nonatomic, strong) FTTracer *tracer;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) int bindingsCount;
@end
@implementation FTURLSessionInstrumentation
@synthesize enableAutoRumTrack = _enableAutoRumTrack;

static FTURLSessionInstrumentation *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if(self){
        _lock = [[NSLock alloc]init];
        _bindingsCount = 0;
    }
    return self;
}
-(id<FTURLSessionInterceptorProtocol>)interceptor{
    return [FTURLSessionInterceptor shared];
}
-(void)setSdkUrlStr:(NSString *)sdkUrlStr{
    _sdkUrlStr = sdkUrlStr;
}
-(id<FTExternalResourceProtocol>)externalResourceHandler{
    return [FTURLSessionInterceptor shared];
}
-(id<FTTracerProtocol>)tracer{
    return _tracer;
}
- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace enableLinkRumData:(BOOL)enableLinkRumData sampleRate:(int)sampleRate traceType:(NetworkTraceType)traceType{
    _enableAutoTrace = enableAutoTrace;
    [[FTTracer shared] startWithSampleRate:sampleRate traceType:(FTNetworkTraceType)traceType enableLinkRumData:enableLinkRumData];
    _tracer = [FTTracer shared];
    [[FTURLSessionInterceptor shared] setTracer:_tracer];
    if(enableAutoTrace){
        [self.interceptor setTracer:_tracer];
        [self startURLProtocolMonitor];
    }
}
- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler{
    self.interceptor.rumResourceHandeler = handler;
}
-(void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler{
    self.interceptor.intakeUrlHandler = intakeUrlHandler;
}
- (void)startURLProtocolMonitor{
    [self.lock lock];
    [FTURLProtocol startMonitor];
    [FTURLProtocol setDelegate:self];
    [self.lock unlock];
}
- (void)stopURLProtocolMonitor{
    [self.lock lock];
    [FTURLProtocol stopMonitor];
    [self.lock unlock];
}
#pragma mark ========== swizzle ==========
- (void)swizzleURLSession{
    [self.lock lock];
    if(self.bindingsCount==0){
        [self _swizzleURLSession];
    }
    self.bindingsCount++;
    [self.lock unlock];
}
- (void)unswizzleURLSession{
    [self.lock lock];
    if(self.bindingsCount > 1){
        self.bindingsCount--;
    }else if (self.bindingsCount == 1){
        [self _swizzleURLSession];
    }
    [self.lock unlock];
}
- (void)_swizzleURLSession{
    NSError *error = NULL;
    if(@available(iOS 13.0, *)){
        [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithURL:) withMethod:@selector(dataTaskWithURL:) error:&error];
        [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithURL:completionHandler:) withMethod:@selector(dataTaskWithURL:completionHandler:) error:&error];
    }
    [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithRequest:) withMethod:@selector(dataTaskWithRequest:) error:&error];
    [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithRequest:completionHandler:) withMethod:@selector(dataTaskWithRequest:completionHandler:) error:&error];
}
#pragma mark ========== FTAutoInterceptorProtocol ==========
-(void)setEnableAutoRumTrack:(BOOL)enableAutoRumTrack{
    _enableAutoRumTrack = enableAutoRumTrack;
    if(enableAutoRumTrack){
        [self startURLProtocolMonitor];
    }
}
-(BOOL)enableAutoRumTrack{
    return _enableAutoRumTrack;
}
-(NSURLRequest *)interceptRequest:(NSURLRequest *)request{
    if(!self.enableAutoTrace){
        return request;
    }
    return [self.interceptor interceptRequest:request];
}
- (BOOL)isTraceUrl:(NSURL *)url{
    BOOL trace = YES;
    if (self.sdkUrlStr) {
        if (url.port) {
            trace = !([url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host]&&[url.port isEqual:[NSURL URLWithString:self.sdkUrlStr].port]);
        }else{
            trace = ![url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host];
        }
        if(trace){
            return [self.interceptor isTraceUrl:url];
        }
    }
    return trace;
}
- (void)resetInstance{
    [[FTTracer shared] shutDown];
    onceToken = 0;
    sharedInstance =nil;
}

@end
