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
#import "FTDateUtil.h"
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
#import "FTURLConnectionInstrumentation.h"
#import "FTVisitorIDManager.h"

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
@property (atomic, assign) BOOL shouldVisitorIDInterceptor;
@property (atomic, assign) BOOL didWarnVisitorHeaderReplacement;
- (void)injectVisitorIDIntoTask:(NSURLSessionTask *)task;
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
        _shouldVisitorIDInterceptor = NO;
    }
    return self;
}

- (void)shutDown {
    [self disableAutomaticRegistration];
    [[FTURLSessionInterceptor existingInstance] shutDown];
    _tracer = nil;
}

#pragma mark - Configuration Management

- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace
              enableLinkRumData:(BOOL)enableLinkRumData
              traceSamplingRate:(float)traceSamplingRate
                      traceType:(NetworkTraceType)traceType
               traceInterceptor:(TraceInterceptor)traceInterceptor
                    serviceName:(NSString *)serviceName {
    [self swizzleURLSession];
    
    _tracer = [[FTTracer alloc] initWithTraceSamplingRate:traceSamplingRate
                                                traceType:(NetworkTraceType)traceType
                                              serviceName:serviceName
                                          enableAutoTrace:enableAutoTrace
                                        enableLinkRumData:enableLinkRumData];
    
    FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
    [interceptor setTracer:_tracer];
    interceptor.traceInterceptor = traceInterceptor;
    self.shouldTraceInterceptor = enableAutoTrace;
}

- (void)setEnableAutoRumTrace:(BOOL)enableAutoRumTrack
           resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler
     resourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider
       sessionTaskErrorFilter:(SessionTaskErrorFilter)sessionTaskErrorFilter {
    [self swizzleURLSession];
    
    FTURLSessionInterceptor *interceptor = [FTURLSessionInterceptor shared];
    interceptor.resourceUrlHandler = resourceUrlHandler;
    interceptor.resourcePropertyProvider = resourcePropertyProvider;
    interceptor.sessionTaskErrorFilter = sessionTaskErrorFilter;
    self.shouldRUMInterceptor = enableAutoRumTrack;
}

- (void)updateTraceSamplingRate:(float)traceSamplingRate {
    [_tracer updateTraceSamplingRate:traceSamplingRate];
}

- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler {
    [FTURLSessionInterceptor shared].rumResourceHandler = handler;
}

- (void)setVisitorIDEnabled:(BOOL)enabled {
    if (enabled) {
        [self swizzleURLSession];
    }
    self.shouldVisitorIDInterceptor = enabled;
}

- (void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler {
    [FTURLSessionInterceptor shared].intakeUrlHandler = intakeUrlHandler;
}

/// Disables automatic collection
- (void)disableAutomaticRegistration {
    self.shouldRUMInterceptor = NO;
    self.shouldTraceInterceptor = NO;
    self.shouldVisitorIDInterceptor = NO;
}

#pragma mark - Interceptor Management

- (id<FTURLSessionInterceptorProtocol>)interceptor {
    return [FTURLSessionInterceptor existingInstance];
}

- (id<FTExternalResourceProtocol>)externalResourceHandler {
    return [FTURLSessionInterceptor existingInstance];
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

            // Automatic completions look up an existing lifecycle at forwarding time.
            // Task ownership rejects old tasks, without retaining a stopped collector.
            id<FTURLSessionInterceptorProtocol> forwardingDelegate =
                [rumInterceptor isKindOfClass:FTURLSessionInterceptor.class] ? nil : rumInterceptor;
            __block __weak NSURLSessionDataTask *taskReference;
            CompletionHandler originalHandler = [completionHandler copy];
            CompletionHandler handler = originalHandler;

            if (originalHandler) {
                handler = ^(NSData *data, NSURLResponse *response, NSError *error) {
                    uint64_t endTime = [FTDateUtil continuousTime];
                    @try {
                        originalHandler(data, response, error);
                    } @finally {
                        @try {
                            NSURLSessionDataTask *task = taskReference;
                            id<FTURLSessionInterceptorProtocol> taskInterceptor = forwardingDelegate ?: [FTURLSessionInstrumentation sharedInstance].interceptor;
                            if (task) {
                                if (data) {
                                    [taskInterceptor taskReceivedCompleteData:task data:data];
                                }
                                if ([taskInterceptor respondsToSelector:@selector(taskCompleted:error:endTime:)]) {
                                    [taskInterceptor taskCompleted:task error:error endTime:endTime];
                                } else {
                                    [taskInterceptor taskCompleted:task error:error];
                                }
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

        id<FTURLSessionInterceptorProtocol> forwardingDelegate =
            [rumInterceptor isKindOfClass:FTURLSessionInterceptor.class] ? nil : rumInterceptor;
        __block __weak NSURLSessionDataTask *taskReference;
        CompletionHandler originalHandler = [completionHandler copy];
        CompletionHandler handler = originalHandler;

        if (originalHandler) {
            handler = ^(NSData *data, NSURLResponse *response, NSError *error) {
                uint64_t endTime = [FTDateUtil continuousTime];
                @try {
                    originalHandler(data, response, error);
                } @finally {
                    @try {
                        NSURLSessionDataTask *task = taskReference;
                        id<FTURLSessionInterceptorProtocol> taskInterceptor = forwardingDelegate ?: [FTURLSessionInstrumentation sharedInstance].interceptor;
                        if (task) {
                            if (data) {
                                [taskInterceptor taskReceivedCompleteData:task data:data];
                            }
                            if ([taskInterceptor respondsToSelector:@selector(taskCompleted:error:endTime:)]) {
                                [taskInterceptor taskCompleted:task error:error endTime:endTime];
                            } else {
                                [taskInterceptor taskCompleted:task error:error];
                            }
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

    __unsafe_unretained Class receiveDataClass = Nil;
    __unsafe_unretained Class completeClass = Nil;
    __unsafe_unretained Class collectMetricsClass = Nil;
    __unsafe_unretained Class webSocketOpenClass = Nil;
    [FTSwizzler getRealDelegateClassFromSelector:receiveDataSelector proxy:delegate result:&receiveDataClass];
    [FTSwizzler getRealDelegateClassFromSelector:completeSelector proxy:delegate result:&completeClass];
    [FTSwizzler getRealDelegateClassFromSelector:collectMetricsSelector proxy:delegate result:&collectMetricsClass];
    [FTSwizzler getRealDelegateClassFromSelector:webSocketOpenSelector proxy:delegate result:&webSocketOpenClass];
    
    // Ensure the delegate class implements the necessary methods
    [self addNoopMethodIfNeededToClass:receiveDataClass selector:receiveDataSelector];
    [self addNoopMethodIfNeededToClass:completeClass selector:completeSelector];
    [self addNoopMethodIfNeededToClass:collectMetricsClass selector:collectMetricsSelector];
    [self addNoopMethodIfNeededToClass:webSocketOpenClass selector:webSocketOpenSelector];
    
    if (receiveDataClass) {
        [self swizzleReceiveDataMethodForClass:receiveDataClass];
    }
    if (completeClass) {
        [self swizzleCompleteMethodForClass:completeClass];
    }
    if (collectMetricsClass) {
        [self swizzleCollectMetricsMethodForClass:collectMetricsClass];
    }
    if (webSocketOpenClass) {
        [self swizzleWebSocketOpenMethodForClass:webSocketOpenClass];
    }
}

/// Adds a no-op method to the class if necessary
- (void)addNoopMethodIfNeededToClass:(Class)targetClass selector:(SEL)selector {
    if (targetClass && !class_respondsToSelector(targetClass, selector)) {
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
    if (FTRequestIsOwnedByURLConnection(currentRequest)) {
        return;
    }
    if ([self isFTIntakeRequest:currentRequest]) {
        return;
    }
    id<NSURLSessionDelegate> delegate = [task ft_delegate];
    id<FTURLSessionInterceptorProtocol> traceInterceptor = [[FTURLSessionInstrumentation sharedInstance] traceInterceptor:delegate];
    id<FTURLSessionInterceptorProtocol> rumInterceptor = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:delegate];
    [traceInterceptor traceInterceptTask:task];
    BOOL supportsVisitorID = [task isKindOfClass:NSURLSessionDataTask.class] ||
        [task isKindOfClass:NSURLSessionDownloadTask.class];
    if (self.shouldVisitorIDInterceptor && supportsVisitorID && !task.ft_isWebSocketTask) {
        [self injectVisitorIDIntoTask:task];
    }
    [rumInterceptor interceptTask:task];
}

- (void)injectVisitorIDIntoTask:(NSURLSessionTask *)task {
    @try {
        @synchronized (task) {
            NSURLRequest *request = task.currentRequest;
            if (!request.URL) {
                return;
            }
            FTVisitorIDRequestSnapshot *snapshot = task.ft_visitorIDSnapshot;
            if (!task.ft_visitorIDWasEvaluated) {
                task.ft_visitorIDWasEvaluated = YES;
                snapshot = [[FTVisitorIDManager sharedInstance] requestSnapshotForURL:request.URL];
                task.ft_visitorIDSnapshot = snapshot;
            }
            if (!snapshot) {
                return;
            }
            NSString *existing = [request valueForHTTPHeaderField:snapshot.headerName];
            if (existing && ![existing isEqualToString:snapshot.value]) {
                @synchronized (self) {
                    if (!self.didWarnVisitorHeaderReplacement) {
                        self.didWarnVisitorHeaderReplacement = YES;
                        FTInnerLogWarning(@"Existing Visitor ID header replaced with SDK-managed value");
                    }
                }
            }
            NSMutableURLRequest *mutableRequest = [request mutableCopy];
            [mutableRequest setValue:snapshot.value forHTTPHeaderField:snapshot.headerName];
            [task setValue:mutableRequest forKey:@"currentRequest"];
        }
    } @catch (NSException *exception) {
        FTInnerLogWarning(@"Visitor ID request injection failed: %@", exception.reason);
    }
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
