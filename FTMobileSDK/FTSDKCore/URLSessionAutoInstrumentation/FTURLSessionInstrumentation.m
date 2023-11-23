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
#import "FTURLSessionInterceptor+Private.h"
#import "FTTracer.h"
#import <objc/runtime.h>
@interface FTURLSessionInstrumentation()
/// sdk 内部的数据上传 url
@property (nonatomic, copy) NSString *sdkUrlStr;
@property (nonatomic, assign) BOOL enableAutoTrace;
@property (nonatomic, strong) FTTracer *tracer;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, assign) int bindingsCount;
@property (nonatomic, assign) BOOL autoRegistration;
@end
@implementation FTURLSessionInstrumentation
@synthesize enableAutoRumTrack = _enableAutoRumTrack;

static FTURLSessionInstrumentation *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
        [sharedInstance swizzleURLSession];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if(self){
        _lock = [[NSRecursiveLock alloc]init];
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
- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace enableLinkRumData:(BOOL)enableLinkRumData sampleRate:(int)sampleRate traceType:(FTNetworkTraceType)traceType{
    _enableAutoTrace = enableAutoTrace;
    _tracer = [[FTTracer alloc] initWithSampleRate:sampleRate traceType:(NetworkTraceType)traceType enableLinkRumData:enableLinkRumData];
    [self.interceptor setTracer:_tracer];
    if(enableAutoTrace){
        [self enableAutomaticRegistration];
    }
}
- (void)setEnableAutoRumTrack:(BOOL)enableAutoRumTrack resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler{
    _enableAutoRumTrack = enableAutoRumTrack;
    self.interceptor.resourceUrlHandler = resourceUrlHandler;
    if(enableAutoRumTrack){
        [self enableAutomaticRegistration];
    }
}
- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler{
    self.interceptor.rumResourceHandeler = handler;
}
-(void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler{
    self.interceptor.intakeUrlHandler = intakeUrlHandler;
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
    if(@available(iOS 13.0,macOS 10.15,*)){
        [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithURL:) withMethod:@selector(dataTaskWithURL:) error:&error];
        [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithURL:completionHandler:) withMethod:@selector(dataTaskWithURL:completionHandler:) error:&error];
    }
    [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithRequest:) withMethod:@selector(dataTaskWithRequest:) error:&error];
    [NSURLSession ft_swizzleMethod:@selector(ft_dataTaskWithRequest:completionHandler:) withMethod:@selector(dataTaskWithRequest:completionHandler:) error:&error];
}
/// 启用自动注册`FTURLSessionDelegate`。
/// 在调用这个方法之后，每次您使用`init(configuration:delegate:delegateQueue:)`方法初始化一个`URLSession`时
/// 委托将自动被替换为`FTURLSessionDelegate`，它将记录所有需要的事件并将方法转发给原始委托。
///
/// - 注意:不支持 async/await URLSession APIs
///
/// 在实例化`URLSession`之前在代码中的任何地方调用它
/// ```objc
/// [FTURLSessionDelegate enableAutomaticRegistration];
///
/// [NSURLSession sessionWithConfiguration:configuration delegate:YourDelegate delegateQueue:nil];
/// ```
- (void)enableAutomaticRegistration{
    [self.lock lock];
    if(self.autoRegistration == NO){
        self.autoRegistration = YES;
        [self _swizzleURLSessionInit];
        [self swizzleURLSession];
    }
    [self.lock unlock];
}
/// 关闭自动注册`FTURLSessionDelegate`。
- (void)disableAutomaticRegistration{
    [self.lock lock];
    if(self.autoRegistration == YES){
        self.autoRegistration = NO;
        [self _swizzleURLSessionInit];
        [self unswizzleURLSession];
    }
    [self.lock unlock];
}
- (void)_swizzleURLSessionInit{
    NSError *error = NULL;
    [NSURLSession ft_swizzleClassMethod:@selector(ft_sessionWithConfiguration:delegate:delegateQueue:) withClassMethod:@selector(sessionWithConfiguration:delegate:delegateQueue:) error:&error];
}

#pragma mark ========== FTAutoInterceptorProtocol ==========
-(BOOL)enableAutoRumTrack{
    return _enableAutoRumTrack;
}
-(NSURLRequest *)interceptRequest:(NSURLRequest *)request{
    if(!self.enableAutoTrace){
        return request;
    }
    return [self.interceptor interceptRequest:request];
}
- (BOOL)isNotSDKInsideUrl:(NSURL *)url{
    BOOL trace = YES;
    if (self.sdkUrlStr) {
        if (url.port) {
            trace = !([url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host]&&[url.port isEqual:[NSURL URLWithString:self.sdkUrlStr].port]);
        }else{
            trace = ![url.host isEqualToString:[NSURL URLWithString:self.sdkUrlStr].host];
        }
    }
    return trace;
}
- (void)resetInstance{
    [self disableAutomaticRegistration];
    [self unswizzleURLSession];
    [[FTURLSessionInterceptor shared] shutDown];
    onceToken = 0;
    sharedInstance =nil;
}

@end
