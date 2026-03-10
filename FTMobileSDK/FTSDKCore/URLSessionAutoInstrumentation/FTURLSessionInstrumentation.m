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
#import "FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTTracer.h"
#import <objc/runtime.h>
#import "NSURLSessionTask+FTSwizzler.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTURLSessionDelegate+Private.h"
#import "FTLog+Private.h"
#import "FTDURLSessionDelegate.h"

typedef void (^CompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

// MARK: - Associated Object Keys
static void *const kFTReceiveDataSelector = (void *)&kFTReceiveDataSelector;
static void *const kFTCompleteSelector = (void *)&kFTCompleteSelector;
static void *const kFTCollectMetricsSelector = (void *)&kFTCollectMetricsSelector;
static void *const kFTConformsToFTProtocol = (void *)&kFTConformsToFTProtocol;
static void *const kFTURLSessionTaskResume = (void *)&kFTURLSessionTaskResume;
static void *const kFTURLSessionDataTaskWithURL = (void *)&kFTURLSessionDataTaskWithURL;
static void *const kFTURLSessionDataTaskWithRequest = (void *)&kFTURLSessionDataTaskWithRequest;

#pragma mark - Utility Functions

/// Checks if the delegate conforms to the FTURLSessionDelegateProviding protocol
/// @note The conformsToProtocol method has overhead, Apple recommends caching results locally to reduce calls
static BOOL delegateConformsToFTProtocol(id delegate) {
    if (!delegate) {
        return NO;
    }
    
    NSNumber *conformNum = objc_getAssociatedObject(delegate, kFTConformsToFTProtocol);
    if (conformNum != nil) {
        return [conformNum boolValue];
    } else {
        BOOL conform = [delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)];
        objc_setAssociatedObject(delegate, kFTConformsToFTProtocol, @(conform), OBJC_ASSOCIATION_RETAIN);
        return conform;
    }
}

// MARK: - Class Implementation
@interface FTURLSessionInstrumentation()
@property (nonatomic, strong) FTTracer *tracer;
@property (atomic, assign, readwrite) BOOL shouldTraceInterceptor;
@property (atomic, assign, readwrite) BOOL shouldRUMInterceptor;
@end

@implementation FTURLSessionInstrumentation

static FTURLSessionInstrumentation *sharedInstance = nil;
static dispatch_once_t onceToken;

// MARK: - Lifecycle Management
#pragma mark - Lifecycle Management

+ (void)load {
#if !defined(FT_DISABLE_SWIZZLING_RESOURCE) || FT_DISABLE_SWIZZLING_RESOURCE == 0
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Swizzle sessionWithConfiguration:delegate:delegateQueue: method
        FTSwizzlerClassMethod(NSURLSession.class,
                              @selector(sessionWithConfiguration:delegate:delegateQueue:),
                              FTSWReturnType(NSURLSession *),
                              FTSWArguments(NSURLSessionConfiguration *configuration,
                                            id <NSURLSessionDelegate> delegate,
                                            NSOperationQueue *queue),
                              FTSWReplacement({
            id<NSURLSessionDelegate> realDelegate = delegate;
            @try {
                if (delegate == nil) {
                    realDelegate = [[FTDURLSessionDelegate alloc] init];
                } else if (!delegateConformsToFTProtocol(realDelegate)) {
                    [[FTURLSessionInstrumentation sharedInstance] enableSessionDelegate:realDelegate];
                }
            } @catch (NSException *exception) {
                FTInnerLogError(@"exception: %@", exception);
            }
            return FTSWCallOriginal(configuration, realDelegate, queue);
        }));
    });
#endif
}

+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTURLSessionInstrumentation alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _shouldRUMInterceptor = NO;
        _shouldTraceInterceptor = NO;
    }
    return self;
}

- (void)shutDown {
    [self disableAutomaticRegistration];
    [[FTURLSessionInterceptor shared] shutDown];
    _tracer = nil;
}

#pragma mark - Configuration Management

- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace
              enableLinkRumData:(BOOL)enableLinkRumData
                     sampleRate:(int)sampleRate
                      traceType:(NetworkTraceType)traceType
               traceInterceptor:(TraceInterceptor)traceInterceptor
                    serviceName:(NSString *)serviceName {
    [self swizzleURLSession];
    
    _tracer = [[FTTracer alloc] initWithSampleRate:sampleRate
                                         traceType:(NetworkTraceType)traceType
                                       serviceName:serviceName
                                   enableAutoTrace:enableAutoTrace
                                 enableLinkRumData:enableLinkRumData];
    
    [self.interceptor setTracer:_tracer];
    self.interceptor.traceInterceptor = traceInterceptor;
    self.shouldTraceInterceptor = enableAutoTrace;
}

- (void)setEnableAutoRumTrace:(BOOL)enableAutoRumTrack
           resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler
     resourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider
       sessionTaskErrorFilter:(SessionTaskErrorFilter)sessionTaskErrorFilter {
    [self swizzleURLSession];
    
    self.interceptor.resourceUrlHandler = resourceUrlHandler;
    self.shouldRUMInterceptor = enableAutoRumTrack;
    self.interceptor.resourcePropertyProvider = resourcePropertyProvider;
    self.interceptor.sessionTaskErrorFilter = sessionTaskErrorFilter;
}

- (void)updateTraceSampleRate:(int)sampleRate {
    [_tracer updateTraceSampleRate:sampleRate];
}

- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler {
    self.interceptor.rumResourceHandler = handler;
}

- (void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler {
    self.interceptor.intakeUrlHandler = intakeUrlHandler;
}

/// Disables automatic collection
- (void)disableAutomaticRegistration {
    self.shouldRUMInterceptor = NO;
    self.shouldTraceInterceptor = NO;
}

#pragma mark - Interceptor Management

- (id<FTURLSessionInterceptorProtocol>)interceptor {
    return [FTURLSessionInterceptor shared];
}

- (id<FTExternalResourceProtocol>)externalResourceHandler {
    return [FTURLSessionInterceptor shared];
}

- (id<FTTracerProtocol>)tracer {
    return _tracer;
}

- (id<FTURLSessionInterceptorProtocol>)traceInterceptor:(id<NSURLSessionDelegate>)delegate {
    if (delegateConformsToFTProtocol(delegate)) {
        return ((id<FTURLSessionDelegateProviding>)delegate).ftURLSessionDelegate;
    } else if (self.shouldTraceInterceptor) {
        return self.interceptor;
    }
    return nil;
}

- (id<FTURLSessionInterceptorProtocol>)rumInterceptor:(id<NSURLSessionDelegate>)delegate {
    if (delegateConformsToFTProtocol(delegate)) {
        return ((id<FTURLSessionDelegateProviding>)delegate).ftURLSessionDelegate;
    } else if (self.shouldRUMInterceptor) {
        return self.interceptor;
    }
    return nil;
}

// MARK: - Swizzling Management
#pragma mark - URLSession swizzle

- (void)swizzleURLSession {
#if !defined(FT_DISABLE_SWIZZLING_RESOURCE) || FT_DISABLE_SWIZZLING_RESOURCE == 0
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleDataTaskWithURL];
        [self swizzleDataTaskWithRequest];
        [self swizzleTaskResume];
    });
#endif
}

/// Swizzle dataTaskWithURL:completionHandler: method
- (void)swizzleDataTaskWithURL {
    if (@available(iOS 13.0, macOS 10.15, *)) {
        FTSwizzlerInstanceMethod([NSURLSession class],
                                 @selector(dataTaskWithURL:completionHandler:),
                                 FTSWReturnType(NSURLSessionDataTask *),
                                 FTSWArguments(NSURL *url, CompletionHandler completionHandler),
                                 FTSWReplacement({
            NSURLSession *session = self;
            id<FTURLSessionInterceptorProtocol> rumIntercepter = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:session.delegate];
            CompletionHandler handler = completionHandler;
            
            if (rumIntercepter) {
                __block NSURLSessionDataTask *taskReference;
                if (handler) {
                    CompletionHandler newCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
                        completionHandler(data, response, error);
                        if (taskReference) {
                            if (data) {
                                [rumIntercepter taskReceivedData:taskReference data:data];
                            }
                            [rumIntercepter taskCompleted:taskReference error:error];
                        }
                    };
                    handler = newCompletionHandler;
                }
                
                NSURLSessionDataTask *task = FTSWCallOriginal(url, handler);
                task.ft_hasCompletion = handler ? YES : NO;
                taskReference = task;
                return task;
            }
            return FTSWCallOriginal(url, completionHandler);
        }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTURLSessionDataTaskWithURL);
    }
}

/// Swizzle dataTaskWithRequest:completionHandler: method
- (void)swizzleDataTaskWithRequest {
    FTSwizzlerInstanceMethod([NSURLSession class],
                             @selector(dataTaskWithRequest:completionHandler:),
                             FTSWReturnType(NSURLSessionDataTask *),
                             FTSWArguments(NSURLRequest *request, CompletionHandler completionHandler),
                             FTSWReplacement({
        @try {
            NSURLSession *session = self;
            id<FTURLSessionInterceptorProtocol> rumIntercepter = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:session.delegate];
            CompletionHandler handler = completionHandler;
            
            if (rumIntercepter) {
                __block NSURLSessionDataTask *taskReference;
                if (handler) {
                    CompletionHandler newCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
                        completionHandler(data, response, error);
                        if (taskReference) {
                            if (data) {
                                [rumIntercepter taskReceivedData:taskReference data:data];
                            }
                            [rumIntercepter taskCompleted:taskReference error:error];
                        }
                    };
                    handler = newCompletionHandler;
                }
                
                NSURLSessionDataTask *task = FTSWCallOriginal(request, handler);
                task.ft_hasCompletion = handler ? YES : NO;
                taskReference = task;
                return task;
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception: %@", exception);
        }
        return FTSWCallOriginal(request, completionHandler);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTURLSessionDataTaskWithRequest);
}

/// Swizzle task resume method
- (void)swizzleTaskResume {
    Class taskClass = NSClassFromString(@"__NSCFLocalSessionTask");
    if (taskClass) {
        FTSwizzlerInstanceMethod(taskClass,
                                 @selector(resume),
                                 FTSWReturnType(void),
                                 FTSWArguments(),
                                 FTSWReplacement({
            [[FTURLSessionInstrumentation sharedInstance] interceptResume:self];
            FTSWCallOriginal();
        }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTURLSessionTaskResume);
    }
}

#pragma mark - NSURLSessionDelegate swizzle

- (void)enableSessionDelegate:(id<NSURLSessionDelegate>)delegate {
    SEL receiveDataSelector = @selector(URLSession:dataTask:didReceiveData:);
    SEL completeSelector = @selector(URLSession:task:didCompleteWithError:);
    SEL collectMetricsSelector = @selector(URLSession:task:didFinishCollectingMetrics:);
    
    Class receiveDataClass = [FTSwizzler realDelegateClassFromSelector:receiveDataSelector proxy:delegate];
    Class completeClass = [FTSwizzler realDelegateClassFromSelector:completeSelector proxy:delegate];
    Class collectMetricsClass = [FTSwizzler realDelegateClassFromSelector:collectMetricsSelector proxy:delegate];
    
    // Ensure the delegate class implements the necessary methods
    [self addMethodIfNeededToClass:receiveDataClass selector:receiveDataSelector];
    [self addMethodIfNeededToClass:completeClass selector:completeSelector];
    [self addMethodIfNeededToClass:collectMetricsClass selector:collectMetricsSelector];
    
    [self swizzleReceiveDataMethodForClass:receiveDataClass];
    [self swizzleCompleteMethodForClass:completeClass];
    [self swizzleCollectMetricsMethodForClass:collectMetricsClass];
}

/// Adds a method to the class if necessary
- (void)addMethodIfNeededToClass:(Class)targetClass selector:(SEL)selector {
    if (![FTSwizzler realDelegateClass:targetClass respondsToSelector:selector]) {
        void (^block)(id, id, id, id) = ^(id delegate, NSURLSession *session, NSURLSessionDataTask *task, id param) {
            // Empty implementation, just to ensure the method exists
        };
        IMP imp = imp_implementationWithBlock(block);
        
        // Determine the method signature based on the selector
        const char *typeEncoding = [self typeEncodingForSelector:selector];
        class_addMethod(targetClass, selector, imp, typeEncoding);
    }
}

/// Gets the type encoding for the selector
- (const char *)typeEncodingForSelector:(SEL)selector {
    if (selector == @selector(URLSession:dataTask:didReceiveData:)) {
        return "v@:@@@";
    } else if (selector == @selector(URLSession:task:didCompleteWithError:)) {
        return "v@:@@@";
    } else if (selector == @selector(URLSession:task:didFinishCollectingMetrics:)) {
        return "v@:@@@";
    }
    return "v@:@@@";
}

/// Swizzle the method for receiving data
- (void)swizzleReceiveDataMethodForClass:(Class)targetClass {
    FTSwizzlerInstanceMethod(targetClass,
                             @selector(URLSession:dataTask:didReceiveData:),
                             FTSWReturnType(void),
                             FTSWArguments(NSURLSession *session, NSURLSessionDataTask *task, NSData *data),
                             FTSWReplacement({
        if (FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor) {
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskReceivedData:task data:data];
        }
        FTSWCallOriginal(session, task, data);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTReceiveDataSelector);
}

/// Swizzle the method for completing tasks
- (void)swizzleCompleteMethodForClass:(Class)targetClass {
    FTSwizzlerInstanceMethod(targetClass,
                             @selector(URLSession:task:didCompleteWithError:),
                             FTSWReturnType(void),
                             FTSWArguments(NSURLSession *session, NSURLSessionDataTask *task, NSError *error),
                             FTSWReplacement({
        if (FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor) {
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskCompleted:task error:error];
        }
        FTSWCallOriginal(session, task, error);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTCompleteSelector);
}

/// Swizzle the method for collecting metrics
- (void)swizzleCollectMetricsMethodForClass:(Class)targetClass {
    FTSwizzlerInstanceMethod(targetClass,
                             @selector(URLSession:task:didFinishCollectingMetrics:),
                             FTSWReturnType(void),
                             FTSWArguments(NSURLSession *session, NSURLSessionDataTask *task, NSURLSessionTaskMetrics *metrics),
                             FTSWReplacement({
        if (FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor) {
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskMetricsCollected:task metrics:metrics custom:NO];
        }
        FTSWCallOriginal(session, task, metrics);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTCollectMetricsSelector);
}

#pragma mark - NSURLSessionTask Resume

/// Intercepts the resume method of the task
- (void)interceptResume:(NSURLSessionTask *)task {
    NSURLRequest *currentRequest = task.currentRequest;
    if (!currentRequest) {
        return;
    }
    
    if ([self isFTIntakeRequest:currentRequest]) {
        return;
    }
    
    id<FTURLSessionInterceptorProtocol> traceInterceptor = [[FTURLSessionInstrumentation sharedInstance] traceInterceptor:[task ft_delegate]];
    id<FTURLSessionInterceptorProtocol> rumInterceptor = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:[task ft_delegate]];
    [traceInterceptor traceInterceptTask:task];
    [rumInterceptor interceptTask:task];
}

- (BOOL)isFTIntakeRequest:(NSURLRequest *)request{
    if (request == nil) {
        return NO;
    }
    NSString *pkgIdValue = [request valueForHTTPHeaderField:FT_HTTP_HEADER_X_PKG_ID];
    if (pkgIdValue && [pkgIdValue hasPrefix:@"rumm-"]) {
        return YES;
    }
    return NO;
}

@end
