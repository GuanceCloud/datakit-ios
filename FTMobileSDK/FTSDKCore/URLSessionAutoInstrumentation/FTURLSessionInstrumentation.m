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
#import "NSURLSessionTask+FTSwizzler.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTURLSessionDelegate+Private.h"
#import "FTLog+Private.h"
static void *const kFTReceiveDataSelector = (void *)&kFTReceiveDataSelector;
static void *const kFTCompleteSelector = (void *)&kFTCompleteSelector;
static void *const kFTCollectMetricsSelector = (void *)&kFTCollectMetricsSelector;
static void *const kFTConformsToFTProtocol = (void *)&kFTConformsToFTProtocol;

//conformsToProtocol 方法有损耗，苹果建议本地缓存结果减少调用
static BOOL delegateConformsToFTProtocol(id delegate){
    if(!delegate){
        return NO;
    }
    NSNumber *conformNum = objc_getAssociatedObject(delegate, kFTConformsToFTProtocol);
    if(conformNum != nil){
        return [conformNum boolValue];
    }else{
        BOOL conform = [delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)];
        objc_setAssociatedObject(delegate, kFTConformsToFTProtocol, @(conform), OBJC_ASSOCIATION_RETAIN);
        return conform;
    }
}
@interface FTURLSessionInstrumentation()
/// sdk 内部的数据上传 url
@property (nonatomic, copy) NSString *sdkUrlStr;
@property (nonatomic, strong) FTTracer *tracer;
@property (atomic, assign, readwrite) BOOL shouldTraceInterceptor;
@property (atomic, assign, readwrite) BOOL shouldRUMInterceptor;
@property (nonatomic, copy) NSString *serviceName;
@end
@implementation FTURLSessionInstrumentation

static FTURLSessionInstrumentation *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTURLSessionInstrumentation alloc] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    self = [super init];
    if(self){
        _shouldRUMInterceptor = NO;
        _shouldTraceInterceptor = NO;
    }
    return self;
}
-(id<FTURLSessionInterceptorProtocol>)interceptor{
    return [FTURLSessionInterceptor shared];
}
-(void)setSdkUrlStr:(NSString *)sdkUrlStr serviceName:(NSString *)serviceName{
    self.sdkUrlStr = sdkUrlStr;
    self.serviceName = serviceName;
    FTInnerLogInfo(@"FTURLSessionInstrumentation set sdkUrlStr:%@",sdkUrlStr);
}
-(id<FTExternalResourceProtocol>)externalResourceHandler{
    return [FTURLSessionInterceptor shared];
}
-(id<FTTracerProtocol>)tracer{
    return _tracer;
}
- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace
              enableLinkRumData:(BOOL)enableLinkRumData
                     sampleRate:(int)sampleRate
                      traceType:(FTNetworkTraceType)traceType
               traceInterceptor:(TraceInterceptor)traceInterceptor{
    _tracer = [[FTTracer alloc] initWithSampleRate:sampleRate
                                         traceType:(NetworkTraceType)traceType
                                       serviceName:self.serviceName
                                   enableAutoTrace:enableAutoTrace
                                 enableLinkRumData:enableLinkRumData];
    [self.interceptor setTracer:_tracer];
    self.interceptor.traceInterceptor = traceInterceptor;
    self.shouldTraceInterceptor = enableAutoTrace;
}
- (void)setEnableAutoRumTrace:(BOOL)enableAutoRumTrack
           resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler
     resourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider{
    self.interceptor.resourceUrlHandler = resourceUrlHandler;
    self.shouldRUMInterceptor = enableAutoRumTrack;
    self.interceptor.resourcePropertyProvider = resourcePropertyProvider;
}
- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler{
    self.interceptor.rumResourceHandler = handler;
}
-(void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler{
    self.interceptor.intakeUrlHandler = intakeUrlHandler;
}
/// 关闭自动采集
- (void)disableAutomaticRegistration{
    self.shouldRUMInterceptor = NO;
    self.shouldTraceInterceptor = NO;
}
- (void)enableSessionDelegate:(id <NSURLSessionDelegate>)delegate{
    SEL receiveDataSelector = @selector(URLSession:dataTask:didReceiveData:);
    SEL completeSelector = @selector(URLSession:task:didCompleteWithError:);
    SEL collectMetricsSelector = @selector(URLSession:task:didFinishCollectingMetrics:);
    Class receiveDataClass = [FTSwizzler realDelegateClassFromSelector:receiveDataSelector proxy:delegate];
    Class completeClass = [FTSwizzler realDelegateClassFromSelector:completeSelector proxy:delegate];
    Class collectMetricsClass = [FTSwizzler realDelegateClassFromSelector:collectMetricsSelector proxy:delegate];
    
    if(![FTSwizzler realDelegateClass:receiveDataClass respondsToSelector:receiveDataSelector]){
        void (^receiveDataBlock)(id, id, id, id) = ^(id delegate, NSURLSession *session, NSURLSessionDataTask *task,NSData *data) {
        };
        IMP receiveDataIMP = imp_implementationWithBlock(receiveDataBlock);
        class_addMethod(receiveDataClass, receiveDataSelector, receiveDataIMP, "v@:@@@");
    }
    if(![FTSwizzler realDelegateClass:completeClass respondsToSelector:completeSelector]){
        void (^completeBlock)(id, id, id, id) = ^(id delegate, NSURLSession *session, NSURLSessionDataTask *task,NSError *error) {
        };
        IMP completeIMP = imp_implementationWithBlock(completeBlock);
        class_addMethod(completeClass, completeSelector, completeIMP, "v@:@@@");
    }
    if(![FTSwizzler realDelegateClass:collectMetricsClass respondsToSelector:collectMetricsSelector]){
        void (^collectMetricsBlock)(id, id, id, id) = ^(id delegate, NSURLSession *session, NSURLSessionDataTask *task,NSURLSessionTaskMetrics *metrics) {
        };
        IMP collectMetricsIMP = imp_implementationWithBlock(collectMetricsBlock);
        class_addMethod(collectMetricsClass, collectMetricsSelector, collectMetricsIMP, "v@:@@@");
    }
    FTSwizzlerInstanceMethod(receiveDataClass,
                             receiveDataSelector,
                             FTSWReturnType(void),
                             FTSWArguments(NSURLSession *session, NSURLSessionDataTask *task,NSData *data),
                             FTSWReplacement({
        if(FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor){
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskReceivedData:task data:data];
        }
        FTSWCallOriginal(session,task,data);
    }),
                             FTSwizzlerModeOncePerClassAndSuperclasses,
                             kFTReceiveDataSelector);
    FTSwizzlerInstanceMethod(completeClass, completeSelector, FTSWReturnType(void), FTSWArguments(NSURLSession *session, NSURLSessionDataTask *task,NSError *error), FTSWReplacement({
        if(FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor){
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskCompleted:task error:error];
        }
        FTSWCallOriginal(session,task,error);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTCompleteSelector);
    
    FTSwizzlerInstanceMethod(collectMetricsClass, collectMetricsSelector, FTSWReturnType(void), FTSWArguments(NSURLSession *session, NSURLSessionDataTask *task,NSURLSessionTaskMetrics *metrics), FTSWReplacement({
        if(FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor){
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskMetricsCollected:task metrics:metrics custom:NO];
        }
        FTSWCallOriginal(session,task,metrics);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTCollectMetricsSelector);
}
- (BOOL)isNotSDKInsideUrl:(NSURL *)url{
    if (url == nil || self.sdkUrlStr == nil) {
        if (self.sdkUrlStr == nil) {
            FTInnerLogError(@"FTURLSessionInstrumentation sdkUrlStr is nil");
        }
        return NO;
    }
    NSURL *sdkURL = [NSURL URLWithString:self.sdkUrlStr];
    if (sdkURL == nil) {
        FTInnerLogError(@"FTURLSessionInstrumentation sdkUrlStr is invalid");
        return NO;
    }
    // Compare hosts
    if (![url.host isEqualToString:sdkURL.host]) {
        return YES; // Different host means URL is outside SDK
    }
    // Compare ports
    BOOL isSamePort = (url.port == nil && sdkURL.port == nil) || (url.port && sdkURL.port && [url.port isEqualToNumber:sdkURL.port]);

    return !isSamePort;
}
- (id<FTURLSessionInterceptorProtocol>)traceInterceptor:(id<NSURLSessionDelegate>)delegate{
    if(delegateConformsToFTProtocol(delegate)){
        return ((id<FTURLSessionDelegateProviding>)delegate).ftURLSessionDelegate;
    }else if(self.shouldTraceInterceptor){
        return self.interceptor;
    }
    return nil;
}
- (id<FTURLSessionInterceptorProtocol>)rumInterceptor:(id<NSURLSessionDelegate>)delegate{
    if(delegateConformsToFTProtocol(delegate)){
        return ((id<FTURLSessionDelegateProviding>)delegate).ftURLSessionDelegate;
    }else if(self.shouldRUMInterceptor){
        return self.interceptor;
    }
    return nil;
}
- (void)shutDown{
    [self disableAutomaticRegistration];
    [[FTURLSessionInterceptor shared] shutDown];
    onceToken = 0;
    sharedInstance =nil;
}

@end
