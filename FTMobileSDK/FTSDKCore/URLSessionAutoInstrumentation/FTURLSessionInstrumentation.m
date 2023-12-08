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
@property (nonatomic, strong) FTTracer *tracer;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) int bindingsCount;
@property (nonatomic, assign) BOOL autoRegistration;
@property (atomic, assign, readwrite) BOOL shouldInterceptor;

@end
@implementation FTURLSessionInstrumentation

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
        _lock = [[NSLock alloc]init];
        _bindingsCount = 0;
        _shouldInterceptor = NO;
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
    _tracer = [[FTTracer alloc] initWithSampleRate:sampleRate traceType:(NetworkTraceType)traceType enableAutoTrace:enableAutoTrace enableLinkRumData:enableLinkRumData];
    [self.interceptor setTracer:_tracer];
    if(enableAutoTrace){
        [self enableAutomaticRegistration];
    }
}
- (void)setEnableAutoRumTrack:(BOOL)enableAutoRumTrack resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler{
    self.interceptor.resourceUrlHandler = resourceUrlHandler;
    if(enableAutoRumTrack){
        [self enableAutomaticRegistration];
    }
}
- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler{
    self.interceptor.rumResourceHandler = handler;
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
- (void)unSwizzleURLSession{
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
/// - 注意:不支持 async/await URLSession APIs
///       不支持 [NSURLSession sharedSession]
- (void)enableAutomaticRegistration{
    self.shouldInterceptor = YES;
}
/// 关闭自动采集
- (void)disableAutomaticRegistration{
    self.shouldInterceptor = NO;
}
- (void)enableSessionDelegate:(id <NSURLSessionDelegate>)delegate{
    if (!self.shouldInterceptor) {
        return;
    }
    SEL receiveDataSelector = @selector(URLSession:dataTask:didReceiveData:);
    SEL completeSelector = @selector(URLSession:task:didCompleteWithError:);
    SEL collectMetricsSelector = @selector(URLSession:task:didFinishCollectingMetrics:);
    Class class = [FTSwizzler realDelegateClassFromSelector:receiveDataSelector proxy:delegate];

    if(![FTSwizzler realDelegateClass:class respondsToSelector:receiveDataSelector]){
        void (^receiveDataBlock)(id, SEL, id, id, id) = ^(id object, SEL command, NSURLSession *session, NSURLSessionDataTask *task,NSData *data) {
        };
        IMP receiveDataIMP = imp_implementationWithBlock(receiveDataBlock);
        class_addMethod(class, receiveDataSelector, receiveDataIMP, "v@:@@@");
    }
    if(![FTSwizzler realDelegateClass:class respondsToSelector:completeSelector]){
        void (^completeBlock)(id, SEL, id, id, id) = ^(id object, SEL command, NSURLSession *session, NSURLSessionDataTask *task,NSError *error) {
        };
        IMP completeIMP = imp_implementationWithBlock(completeBlock);
        class_addMethod(class, completeSelector, completeIMP, "v@:@@@");
    }
    if(![FTSwizzler realDelegateClass:class respondsToSelector:collectMetricsSelector]){
        void (^collectMetricsBlock)(id, SEL, id, id, id) = ^(id object, SEL command, NSURLSession *session, NSURLSessionDataTask *task,NSURLSessionTaskMetrics *metrics) {
        };
        IMP collectMetricsIMP = imp_implementationWithBlock(collectMetricsBlock);
        class_addMethod(class, collectMetricsSelector, collectMetricsIMP, "v@:@@@");
    }
    __weak typeof(self) weakSelf = self;
    [FTSwizzler swizzleSelector:receiveDataSelector onClass:class withBlock:^(id object, SEL command, NSURLSession *session, NSURLSessionDataTask *task,NSData *data){
        [weakSelf.interceptor taskReceivedData:task data:data];
    } named:@"receiveDataSelector"];
    [FTSwizzler swizzleSelector:completeSelector onClass:class withBlock:^(id object, SEL command, NSURLSession *session, NSURLSessionDataTask *task,NSError *error){
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        [weakSelf.interceptor taskCompleted:task error:error];
    } named:@"completeSelector"];
    [FTSwizzler swizzleSelector:collectMetricsSelector onClass:class withBlock:^(id object, SEL command, NSURLSession *session, NSURLSessionDataTask *task,NSURLSessionTaskMetrics *metrics){
        [weakSelf.interceptor taskMetricsCollected:task metrics:metrics];
    } named:@"collectMetricsSelector"];
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
    [self unSwizzleURLSession];
    [[FTURLSessionInterceptor shared] shutDown];
    onceToken = 0;
    sharedInstance =nil;
}

@end
