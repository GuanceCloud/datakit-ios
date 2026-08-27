//
//  URLSessionAutoInstrumentation.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/9/13.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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
//

#import "FTURLSessionInstrumentation.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTTracer.h"
#import <objc/runtime.h>
#import "NSURLSessionTask+FTSwizzler.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTURLSessionDelegate+Private.h"
#import "FTInnerLog.h"
#import "FTDURLSessionDelegate.h"

typedef void (^CompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

// MARK: - Associated Object Keys
static void *const kFTReceiveDataSelector = (void *)&kFTReceiveDataSelector;
static void *const kFTCompleteSelector = (void *)&kFTCompleteSelector;
static void *const kFTCollectMetricsSelector = (void *)&kFTCollectMetricsSelector;
static void *const kFTWebSocketOpenSelector = (void *)&kFTWebSocketOpenSelector;
static void *const kFTConformsToFTProtocol = (void *)&kFTConformsToFTProtocol;
static void *const kFTURLSessionTaskResume = (void *)&kFTURLSessionTaskResume;
static void *const kFTURLSessionDataTaskWithURL = (void *)&kFTURLSessionDataTaskWithURL;
static void *const kFTURLSessionDataTaskWithRequest = (void *)&kFTURLSessionDataTaskWithRequest;
static void *const kFTURLSessionWebSocketTaskWithURL = (void *)&kFTURLSessionWebSocketTaskWithURL;
static void *const kFTURLSessionWebSocketTaskWithURLProtocols = (void *)&kFTURLSessionWebSocketTaskWithURLProtocols;
static void *const kFTURLSessionWebSocketTaskWithRequest = (void *)&kFTURLSessionWebSocketTaskWithRequest;

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
        objc_setAssociatedObject(delegate, kFTConformsToFTProtocol, @(conform), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        [self swizzleWebSocketTaskCreation];
        [self swizzleTaskResume];
    });
#endif
}

/// Captures WebSocket URLs before Foundation normalizes ws/wss to http/https on the task request.
- (void)swizzleWebSocketTaskCreation {
    if (@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)) {
        FTSwizzlerInstanceMethod([NSURLSession class],
                                 @selector(webSocketTaskWithURL:),
                                 FTSWReturnType(NSURLSessionTask *),
                                 FTSWArguments(NSURL *url),
                                 FTSWReplacement({
            NSURLSessionTask *task = FTSWCallOriginal(url);
            task.ft_webSocketOriginalURL = url;
            return task;
        }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTURLSessionWebSocketTaskWithURL);

        FTSwizzlerInstanceMethod([NSURLSession class],
                                 @selector(webSocketTaskWithURL:protocols:),
                                 FTSWReturnType(NSURLSessionTask *),
                                 FTSWArguments(NSURL *url, NSArray<NSString *> *protocols),
                                 FTSWReplacement({
            NSURLSessionTask *task = FTSWCallOriginal(url, protocols);
            task.ft_webSocketOriginalURL = url;
            return task;
        }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTURLSessionWebSocketTaskWithURLProtocols);

        FTSwizzlerInstanceMethod([NSURLSession class],
                                 @selector(webSocketTaskWithRequest:),
                                 FTSWReturnType(NSURLSessionTask *),
                                 FTSWArguments(NSURLRequest *request),
                                 FTSWReplacement({
            NSURLSessionTask *task = FTSWCallOriginal(request);
            task.ft_webSocketOriginalURL = request.URL;
            return task;
        }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTURLSessionWebSocketTaskWithRequest);
    }
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
            id<FTURLSessionInterceptorProtocol> rumInterceptor = nil;

            @try {
                rumInterceptor = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:session.delegate];
            } @catch (NSException *exception) {
                FTInnerLogError(@"exception: %@", exception);
            }

            if (!rumInterceptor) {
                return FTSWCallOriginal(url, completionHandler);
            }

            __block __weak NSURLSessionDataTask *taskReference;
            CompletionHandler originalHandler = [completionHandler copy];
            CompletionHandler handler = originalHandler;

            if (originalHandler) {
                handler = ^(NSData *data, NSURLResponse *response, NSError *error) {
                    @try {
                        originalHandler(data, response, error);
                    } @finally {
                        @try {
                            NSURLSessionDataTask *task = taskReference;
                            if (task) {
                                if (data) {
                                    [rumInterceptor taskReceivedCompleteData:task data:data];
                                }
                                [rumInterceptor taskCompleted:task error:error];
                            }
                        } @catch (NSException *exception) {
                            FTInnerLogError(@"exception: %@", exception);
                        }
                    }
                };
            }

            NSURLSessionDataTask *task = FTSWCallOriginal(url, handler);
            task.ft_hasCompletion = handler ? YES : NO;
            taskReference = task;
            return task;
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
        NSURLSession *session = self;
        id<FTURLSessionInterceptorProtocol> rumInterceptor = nil;

        @try {
            rumInterceptor = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:session.delegate];
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception: %@", exception);
        }

        if (!rumInterceptor) {
            return FTSWCallOriginal(request, completionHandler);
        }

        __block __weak NSURLSessionDataTask *taskReference;
        CompletionHandler originalHandler = [completionHandler copy];
        CompletionHandler handler = originalHandler;

        if (originalHandler) {
            handler = ^(NSData *data, NSURLResponse *response, NSError *error) {
                @try {
                    originalHandler(data, response, error);
                } @finally {
                    @try {
                        NSURLSessionDataTask *task = taskReference;
                        if (task) {
                            if (data) {
                                [rumInterceptor taskReceivedCompleteData:task data:data];
                            }
                            [rumInterceptor taskCompleted:task error:error];
                        }
                    } @catch (NSException *exception) {
                        FTInnerLogError(@"exception: %@", exception);
                    }
                }
            };
        }

        NSURLSessionDataTask *task = FTSWCallOriginal(request, handler);
        task.ft_hasCompletion = handler ? YES : NO;
        taskReference = task;
        return task;
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
    SEL webSocketOpenSelector = @selector(URLSession:webSocketTask:didOpenWithProtocol:);
    
    Class receiveDataClass = [FTSwizzler realDelegateClassFromSelector:receiveDataSelector proxy:delegate];
    Class completeClass = [FTSwizzler realDelegateClassFromSelector:completeSelector proxy:delegate];
    Class collectMetricsClass = [FTSwizzler realDelegateClassFromSelector:collectMetricsSelector proxy:delegate];
    Class webSocketOpenClass = [FTSwizzler realDelegateClassFromSelector:webSocketOpenSelector proxy:delegate];
    
    // Ensure the delegate class implements the necessary methods
    [self addNoopMethodIfNeededToClass:receiveDataClass selector:receiveDataSelector];
    [self addNoopMethodIfNeededToClass:completeClass selector:completeSelector];
    [self addNoopMethodIfNeededToClass:collectMetricsClass selector:collectMetricsSelector];
    [self addNoopMethodIfNeededToClass:webSocketOpenClass selector:webSocketOpenSelector];
    
    [self swizzleReceiveDataMethodForClass:receiveDataClass];
    [self swizzleCompleteMethodForClass:completeClass];
    [self swizzleCollectMetricsMethodForClass:collectMetricsClass];
    [self swizzleWebSocketOpenMethodForClass:webSocketOpenClass];
}

/// Adds a no-op method to the class if necessary
- (void)addNoopMethodIfNeededToClass:(Class)targetClass selector:(SEL)selector {
    if (![FTSwizzler realDelegateClass:targetClass respondsToSelector:selector]) {
        Method method = class_getInstanceMethod([FTDURLSessionDelegate class], selector);
        if (!method) {
            return;
        }
        IMP imp = [self noopImplementationForSelector:selector];
        if (!imp) {
            return;
        }
        const char *typeEncoding = method_getTypeEncoding(method);
        if (!class_addMethod(targetClass, selector, imp, typeEncoding)) {
            imp_removeBlock(imp);
        }
    }
}

/// Creates an empty implementation matching the NSURLSession delegate selector signature
- (IMP)noopImplementationForSelector:(SEL)selector {
    if (selector == @selector(URLSession:dataTask:didReceiveData:)) {
        void (^block)(id, NSURLSession *, NSURLSessionDataTask *, NSData *) = ^(__unused id delegate,
                                                                                __unused NSURLSession *session,
                                                                                __unused NSURLSessionDataTask *dataTask,
                                                                                __unused NSData *data) {
        };
        return imp_implementationWithBlock(block);
    } else if (selector == @selector(URLSession:task:didCompleteWithError:)) {
        void (^block)(id, NSURLSession *, NSURLSessionTask *, NSError *) = ^(__unused id delegate,
                                                                             __unused NSURLSession *session,
                                                                             __unused NSURLSessionTask *task,
                                                                             __unused NSError *error) {
        };
        return imp_implementationWithBlock(block);
    } else if (selector == @selector(URLSession:task:didFinishCollectingMetrics:)) {
        void (^block)(id, NSURLSession *, NSURLSessionTask *, NSURLSessionTaskMetrics *) = ^(__unused id delegate,
                                                                                             __unused NSURLSession *session,
                                                                                             __unused NSURLSessionTask *task,
                                                                                             __unused NSURLSessionTaskMetrics *metrics) {
        };
        return imp_implementationWithBlock(block);
    } else if (selector == @selector(URLSession:webSocketTask:didOpenWithProtocol:)) {
        void (^block)(id, NSURLSession *, NSURLSessionTask *, NSString *) = ^(__unused id delegate,
                                                                               __unused NSURLSession *session,
                                                                               __unused NSURLSessionTask *webSocketTask,
                                                                               __unused NSString *protocol) {
        };
        return imp_implementationWithBlock(block);
    }
    return NULL;
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
                             FTSWArguments(NSURLSession *session, NSURLSessionTask *task, NSError *error),
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
                             FTSWArguments(NSURLSession *session, NSURLSessionTask *task, NSURLSessionTaskMetrics *metrics),
                             FTSWReplacement({
        if (FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor) {
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskMetricsCollected:task metrics:metrics custom:NO];
        }
        FTSWCallOriginal(session, task, metrics);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTCollectMetricsSelector);
}

/// Swizzle the WebSocket successful-open callback so a long-lived connection completes its Resource at handshake time.
- (void)swizzleWebSocketOpenMethodForClass:(Class)targetClass {
    FTSwizzlerInstanceMethod(targetClass,
                             @selector(URLSession:webSocketTask:didOpenWithProtocol:),
                             FTSWReturnType(void),
                             FTSWArguments(NSURLSession *session, NSURLSessionTask *webSocketTask, NSString *protocol),
                             FTSWReplacement({
        if (FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor) {
            [FTURLSessionInstrumentation.sharedInstance.interceptor taskWebSocketDidOpen:webSocketTask extraProvider:nil];
        }
        FTSWCallOriginal(session, webSocketTask, protocol);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, kFTWebSocketOpenSelector);
}

#pragma mark - NSURLSessionTask Resume

/// Intercepts the resume method of the task
- (void)interceptResume:(NSURLSessionTask *)task {
    if (![task ft_isSupportedForInstrumentation]) {
        return;
    }
    NSURLRequest *currentRequest = task.currentRequest;
    if (!currentRequest) {
        return;
    }
    if ([self isFTIntakeRequest:currentRequest]) {
        return;
    }
    id<NSURLSessionDelegate> delegate = [task ft_delegate];
    id<FTURLSessionInterceptorProtocol> traceInterceptor = [[FTURLSessionInstrumentation sharedInstance] traceInterceptor:delegate];
    id<FTURLSessionInterceptorProtocol> rumInterceptor = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:delegate];
    [traceInterceptor traceInterceptTask:task];
    [rumInterceptor interceptTask:task];
}

- (BOOL)isFTIntakeRequest:(NSURLRequest *)request{
    if (request == nil) {
        return NO;
    }
    NSString *internalRequestValue = [request valueForHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST];
    if ([internalRequestValue isEqualToString:@"true"]) {
        return YES;
    }
    return NO;
}

@end
