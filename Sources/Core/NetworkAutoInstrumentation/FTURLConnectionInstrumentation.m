//
//  FTURLConnectionInstrumentation.m
//  FTMobileSDK
//

#import "FTURLConnectionInstrumentation.h"
#import "FTURLConnectionDelegate.h"
#import "FTURLConnectionDelegateInstrumentor.h"
#import "FTURLConnectionHandler.h"
#import "FTTracer.h"
#import "FTTraceContext.h"
#import "FTSwizzler.h"
#import "FTDateUtil.h"
#import "FTInnerLog.h"
#import <objc/runtime.h>

NSString * const FTURLConnectionRequestOwnerPropertyKey = @"com.guance.sdk.urlconnection.owner";

BOOL FTRequestIsOwnedByURLConnection(NSURLRequest *request) {
    if (!request) {
        return NO;
    }
    return [NSURLProtocol propertyForKey:FTURLConnectionRequestOwnerPropertyKey inRequest:request] != nil;
}

typedef void (^FTURLConnectionCompletionHandler)(NSURLResponse * _Nullable response,
                                                  NSData * _Nullable data,
                                                  NSError * _Nullable error);

static void *FTURLConnectionHandlerAssociationKey = &FTURLConnectionHandlerAssociationKey;
static void *FTURLConnectionInitKey = &FTURLConnectionInitKey;
static void *FTURLConnectionInitImmediateKey = &FTURLConnectionInitImmediateKey;
static void *FTURLConnectionStartKey = &FTURLConnectionStartKey;
static void *FTURLConnectionCancelKey = &FTURLConnectionCancelKey;
static void *FTURLConnectionQueueIdentityKey = &FTURLConnectionQueueIdentityKey;

NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.")
@interface FTSystemURLConnectionClock : NSObject <FTURLConnectionClock>
@end

@implementation FTSystemURLConnectionClock
- (NSDate *)date { return [FTDateUtil date]; }
- (uint64_t)continuousTime { return [FTDateUtil continuousTime]; }
@end

NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.")
@interface FTURLConnectionPreparation : NSObject
@property (nonatomic, copy) NSURLRequest *request;
@property (nonatomic, strong) id delegate;
@property (nonatomic, strong) FTURLConnectionHandler *handler;
@end

@implementation FTURLConnectionPreparation
@end

@interface FTURLConnectionInstrumentation ()
@property (atomic, assign, readwrite) BOOL shouldTraceInterceptor;
@property (atomic, assign, readwrite) BOOL shouldRUMInterceptor;
@property (atomic, assign) BOOL active;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, strong) FTTracer *tracer;
@property (nonatomic, copy) TraceInterceptor traceInterceptor;
@property (nonatomic, copy) FTResourceUrlHandler resourceUrlHandler;
@property (nonatomic, copy) FTIntakeUrl intakeURLHandlerBlock;
@property (nonatomic, copy) ResourcePropertyProvider resourcePropertyProvider;
@property (nonatomic, copy) SessionTaskErrorFilter sessionTaskErrorFilter;
@property (nonatomic, weak) id<FTRumResourceProtocol> weakRumResourceHandler;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSOperationQueue *completionQueue;
@property (nonatomic, strong) id<FTURLConnectionClock> clock;
@property (nonatomic, strong) NSMapTable<NSString *, FTURLConnectionHandler *> *preparingHandlers;
- (BOOL)isHandlerCurrent:(FTURLConnectionHandler *)handler;
- (nullable FTURLConnectionHandler *)preparingHandlerForRequest:(NSURLRequest *)request;
- (void)installHooksIfNeeded NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.");
@end

@implementation FTURLConnectionInstrumentation

static FTURLConnectionInstrumentation *sharedInstance
    NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.");
static NSObject *sharedInstanceLock;
static NSUInteger nextGeneration;

+ (void)initialize {
    if (self == FTURLConnectionInstrumentation.class) {
        sharedInstanceLock = [[NSObject alloc] init];
    }
}

+ (instancetype)sharedInstance {
    @synchronized (sharedInstanceLock) {
        if (!sharedInstance) {
            sharedInstance = [[self alloc] init];
        }
        return sharedInstance;
    }
}

+ (instancetype)existingInstance {
    @synchronized (sharedInstanceLock) {
        return sharedInstance;
    }
}

+ (void)associateHandler:(FTURLConnectionHandler *)handler withConnection:(NSURLConnection *)connection {
    objc_setAssociatedObject(connection, FTURLConnectionHandlerAssociationKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (FTURLConnectionHandler *)handlerForConnection:(NSURLConnection *)connection {
    if (!connection) {
        return nil;
    }
    FTURLConnectionHandler *handler = objc_getAssociatedObject(connection, FTURLConnectionHandlerAssociationKey);
    if (!handler) {
        // A factory or initializer may deliver callbacks on its returned object
        // before returning. Resolve only its exact UUID, during preparation.
        FTURLConnectionInstrumentation *owner = [self existingInstance];
        if (owner) {
            handler = [owner preparingHandlerForRequest:connection.originalRequest];
            if (handler) {
                [self associateHandler:handler withConnection:connection];
            }
        }
    }
    return [handler.instrumentation isHandlerCurrent:handler] ? handler : nil;
}

- (FTURLConnectionHandler *)preparingHandlerForRequest:(NSURLRequest *)request {
    NSString *identifier = request ? [NSURLProtocol propertyForKey:FTURLConnectionRequestOwnerPropertyKey inRequest:request] : nil;
    if (!identifier) {
        return nil;
    }
    @synchronized (self.preparingHandlers) {
        return [self.preparingHandlers objectForKey:identifier];
    }
}

- (void)finishPreparingHandler:(FTURLConnectionHandler *)handler {
    @synchronized (self.preparingHandlers) {
        [self.preparingHandlers removeObjectForKey:handler.identifier];
    }
}

- (BOOL)isPreparingHandler:(FTURLConnectionHandler *)handler {
    @synchronized (self.preparingHandlers) {
        return [self.preparingHandlers objectForKey:handler.identifier] == handler;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _active = YES;
        @synchronized (sharedInstanceLock) {
            _generation = ++nextGeneration;
        }
        _clock = [[FTSystemURLConnectionClock alloc] init];
        _preparingHandlers = [NSMapTable strongToWeakObjectsMapTable];
        _queue = dispatch_queue_create("com.ft.network.urlconnection", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue, FTURLConnectionQueueIdentityKey, FTURLConnectionQueueIdentityKey, NULL);
        _completionQueue = [[NSOperationQueue alloc] init];
        _completionQueue.name = @"com.ft.network.urlconnection.completion";
        _completionQueue.qualityOfService = NSQualityOfServiceUtility;
    }
    return self;
}

- (void)setEnableAutoRumResource:(BOOL)enabled
              resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler
        resourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider
          sessionTaskErrorFilter:(SessionTaskErrorFilter)sessionTaskErrorFilter {
    self.resourceUrlHandler = resourceUrlHandler;
    self.resourcePropertyProvider = resourcePropertyProvider;
    self.sessionTaskErrorFilter = sessionTaskErrorFilter;
    self.shouldRUMInterceptor = enabled;
    if (enabled) {
        [self installHooksIfNeeded];
    }
}

- (void)setTraceEnableAutoTrace:(BOOL)enabled
              enableLinkRumData:(BOOL)enableLinkRumData
                     sampleRate:(int)sampleRate
                      traceType:(NetworkTraceType)traceType
               traceInterceptor:(TraceInterceptor)traceInterceptor
                    serviceName:(NSString *)serviceName {
    self.tracer = [[FTTracer alloc] initWithSampleRate:sampleRate
                                             traceType:traceType
                                           serviceName:serviceName
                                       enableAutoTrace:enabled
                                     enableLinkRumData:enableLinkRumData];
    self.traceInterceptor = traceInterceptor;
    self.shouldTraceInterceptor = enabled;
    if (enabled) {
        [self installHooksIfNeeded];
    }
}

- (void)updateTraceSampleRate:(int)sampleRate {
    [self.tracer updateTraceSampleRate:sampleRate];
}

- (void)updateResourceEnabled:(BOOL)enabled {
    self.shouldRUMInterceptor = enabled;
    if (enabled) {
        [self installHooksIfNeeded];
    }
}

- (void)updateTraceEnabled:(BOOL)enabled {
    self.shouldTraceInterceptor = enabled;
    self.tracer.enableAutoTrace = enabled;
    if (enabled) {
        [self installHooksIfNeeded];
    }
}

- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler {
    self.weakRumResourceHandler = handler;
}

- (void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler {
    self.intakeURLHandlerBlock = intakeUrlHandler;
}

- (BOOL)isSDKInternalRequest:(NSURLRequest *)request {
    return [[request valueForHTTPHeaderField:FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST] isEqualToString:@"true"];
}

- (BOOL)shouldCollectURL:(NSURL *)URL {
    if (!URL) {
        return NO;
    }
    if (self.resourceUrlHandler) {
        return !self.resourceUrlHandler(URL);
    }
    if (self.intakeURLHandlerBlock) {
        return self.intakeURLHandlerBlock(URL);
    }
    return YES;
}

- (nullable FTURLConnectionPreparation *)prepareRequest:(NSURLRequest *)request delegate:(nullable id)delegate {
    if (!self.active || !request || !request.URL || FTRequestIsOwnedByURLConnection(request) ||
        [self isSDKInternalRequest:request]) {
        return nil;
    }

    BOOL resourceEnabled = self.shouldRUMInterceptor && [self shouldCollectURL:request.URL];
    if (!resourceEnabled && !self.shouldTraceInterceptor) {
        return nil;
    }

    id observerDelegate;
    if (delegate) {
        if (![FTURLConnectionDelegateInstrumentor instrumentDelegate:delegate]) {
            return nil;
        }
        observerDelegate = delegate;
    } else {
        observerDelegate = [[FTURLConnectionDelegate alloc] init];
    }

    FTURLConnectionHandler *handler = [[FTURLConnectionHandler alloc]
        initWithRequest:request
        resourceEnabled:resourceEnabled
        provider:resourceEnabled ? self.resourcePropertyProvider : nil
        errorFilter:resourceEnabled ? self.sessionTaskErrorFilter : nil
        rumResourceHandler:resourceEnabled ? self.weakRumResourceHandler : nil];
    handler.instrumentation = self;
    handler.generation = self.generation;

    NSURLRequest *effectiveRequest = [self requestByApplyingTraceToRequest:request handler:handler];
    NSMutableURLRequest *ownedRequest = [effectiveRequest mutableCopy];
    [NSURLProtocol setProperty:handler.identifier forKey:FTURLConnectionRequestOwnerPropertyKey inRequest:ownedRequest];
    effectiveRequest = [ownedRequest copy];

    [handler updateRequest:effectiveRequest
                   traceID:handler.traceID
                    spanID:handler.spanID
      injectedTraceHeaders:handler.injectedTraceHeaders];

    FTURLConnectionPreparation *preparation = [[FTURLConnectionPreparation alloc] init];
    preparation.request = effectiveRequest;
    preparation.delegate = observerDelegate;
    preparation.handler = handler;
    @synchronized (self.preparingHandlers) {
        [self.preparingHandlers setObject:handler forKey:handler.identifier];
    }
    return preparation;
}

- (NSURLRequest *)requestByApplyingTraceToRequest:(NSURLRequest *)request
                                          handler:(FTURLConnectionHandler *)handler {
    __block NSString *traceID;
    __block NSString *spanID;
    [self.tracer unpackTraceHeader:request.allHTTPHeaderFields ?: @{}
                           handler:^(NSString *candidateTraceID, NSString *candidateSpanID) {
        if (candidateTraceID.length > 0 && candidateSpanID.length > 0) {
            traceID = candidateTraceID;
            spanID = candidateSpanID;
        }
    }];

    if (traceID && spanID) {
        [handler updateRequest:request
                       traceID:self.tracer.enableLinkRumData ? traceID : nil
                        spanID:self.tracer.enableLinkRumData ? spanID : nil
          injectedTraceHeaders:nil];
        return request;
    }
    if (!self.shouldTraceInterceptor || !self.tracer.enableAutoTrace) {
        return request;
    }

    NSDictionary<NSString *, NSString *> *headers;
    if (self.traceInterceptor) {
        FTTraceContext *context = self.traceInterceptor(request);
        if (!context) {
            return request;
        }
        headers = context.traceHeader;
        if (self.tracer.enableLinkRumData && headers.count > 0) {
            [self.tracer unpackTraceHeader:headers handler:^(NSString *headerTraceID, NSString *headerSpanID) {
                if (headerTraceID.length > 0 && headerSpanID.length > 0) {
                    traceID = headerTraceID;
                    spanID = headerSpanID;
                }
            }];
            if (!traceID && context.traceId.length > 0 && context.spanId.length > 0) {
                traceID = context.traceId;
                spanID = context.spanId;
            }
        }
    } else {
        headers = [self.tracer networkTraceHeaderWithUrl:request.URL
                                                 handler:^(NSString *candidateTraceID, NSString *candidateSpanID) {
            if (self.tracer.enableLinkRumData) {
                traceID = candidateTraceID;
                spanID = candidateSpanID;
            }
        }];
    }
    if (headers.count == 0) {
        [handler updateRequest:request traceID:traceID spanID:spanID injectedTraceHeaders:nil];
        return request;
    }
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [mutableRequest setValue:value forHTTPHeaderField:key];
    }];
    NSURLRequest *effectiveRequest = [mutableRequest copy];
    [handler updateRequest:effectiveRequest traceID:traceID spanID:spanID injectedTraceHeaders:headers];
    return effectiveRequest;
}

- (BOOL)isHandlerCurrent:(FTURLConnectionHandler *)handler {
    return self.active && handler.instrumentation == self && handler.generation == self.generation;
}

- (void)activateHandler:(FTURLConnectionHandler *)handler {
    [handler activate];
    [self enqueueHandler:handler block:^{
        [handler reportStartIfNeeded];
        [handler reportTerminalIfNeeded];
    }];
}

- (void)enqueueHandler:(FTURLConnectionHandler *)handler block:(dispatch_block_t)block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![strongSelf isHandlerCurrent:handler]) {
            return;
        }
        @try {
            block();
        } @catch (NSException *exception) {
            FTInnerLogError(@"NSURLConnection instrumentation exception: %@", exception);
        }
    });
}

- (void)handler:(FTURLConnectionHandler *)handler
didReachTerminalWithResponse:(NSURLResponse *)response
          error:(NSError *)error {
    NSDate *date = [self.clock date];
    uint64_t continuousTime = [self.clock continuousTime];
    if (![self isHandlerCurrent:handler]) {
        return;
    }
    if ([handler recordTerminalWithResponse:response error:error date:date continuousTime:continuousTime]) {
        [self enqueueHandler:handler block:^{
            [handler reportTerminalIfNeeded];
        }];
    }
}

- (NSURLRequest *)handler:(FTURLConnectionHandler *)handler
         redirectedRequest:(NSURLRequest *)request
                   response:(NSURLResponse *)response {
    if (![self isHandlerCurrent:handler]) {
        return request;
    }
    return [handler requestByPreparingRedirectRequest:request];
}

- (void)syncProcess {
    if (dispatch_get_specific(FTURLConnectionQueueIdentityKey)) {
        return;
    }
    dispatch_sync(self.queue, ^{});
}

- (void)shutDown {
    self.active = NO;
    self.shouldRUMInterceptor = NO;
    self.shouldTraceInterceptor = NO;
    [self syncProcess];
    self.tracer = nil;
    self.traceInterceptor = nil;
    self.resourceUrlHandler = nil;
    self.intakeURLHandlerBlock = nil;
    self.resourcePropertyProvider = nil;
    self.sessionTaskErrorFilter = nil;
    self.weakRumResourceHandler = nil;
    @synchronized (self.preparingHandlers) {
        [self.preparingHandlers removeAllObjects];
    }
    [self.completionQueue cancelAllOperations];
    @synchronized (sharedInstanceLock) {
        if (sharedInstance == self) {
            sharedInstance = nil;
        }
    }
}

- (void)installHooksIfNeeded {
#if (!defined(FT_DISABLE_SWIZZLING_RESOURCE) || FT_DISABLE_SWIZZLING_RESOURCE == 0) && \
    (!defined(FT_DISABLE_NSURLCONNECTION_INSTRUMENTATION) || FT_DISABLE_NSURLCONNECTION_INSTRUMENTATION == 0)
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        FTSwizzlerInstanceMethod(NSURLConnection.class,
                                 @selector(initWithRequest:delegate:),
                                 FTSWReturnType(NSURLConnection *),
                                 FTSWArguments(NSURLRequest *request, id delegate),
                                 FTSWReplacement({
            FTURLConnectionInstrumentation *instrumentation = [FTURLConnectionInstrumentation existingInstance];
            if (!instrumentation) {
                return FTSWCallOriginal(request, delegate);
            }
            FTURLConnectionHandler *initializingHandler = objc_getAssociatedObject(self, FTURLConnectionHandlerAssociationKey);
            if (initializingHandler && [instrumentation isPreparingHandler:initializingHandler]) {
                return FTSWCallOriginal(request, delegate);
            }
            FTURLConnectionPreparation *preparation;
            @try {
                preparation = [instrumentation prepareRequest:request delegate:delegate];
            } @catch (NSException *exception) {
                FTInnerLogError(@"NSURLConnection preparation exception: %@", exception);
            }
            if (!preparation) {
                FTURLConnectionHandler *nestedHandler = [instrumentation preparingHandlerForRequest:request];
                if (nestedHandler) {
                    [FTURLConnectionInstrumentation associateHandler:nestedHandler withConnection:self];
                }
                return FTSWCallOriginal(request, delegate);
            }
            [FTURLConnectionInstrumentation associateHandler:preparation.handler withConnection:self];
            [preparation.handler recordStartWithDate:[instrumentation.clock date]
                                      continuousTime:[instrumentation.clock continuousTime]];
            NSURLConnection *result;
            @try {
                result = FTSWCallOriginal(preparation.request, preparation.delegate);
                if (result) {
                    [FTURLConnectionInstrumentation associateHandler:preparation.handler withConnection:result];
                }
            } @catch (NSException *exception) {
                [preparation.handler discard];
                @throw;
            } @finally {
                [instrumentation finishPreparingHandler:preparation.handler];
            }
            if (result) {
                [instrumentation activateHandler:preparation.handler];
            } else {
                [preparation.handler discard];
            }
            return result;
        }), FTSwizzlerModeOncePerClassAndSuperclasses, FTURLConnectionInitKey);

        FTSwizzlerInstanceMethod(NSURLConnection.class,
                                 @selector(initWithRequest:delegate:startImmediately:),
                                 FTSWReturnType(NSURLConnection *),
                                 FTSWArguments(NSURLRequest *request, id delegate, BOOL startImmediately),
                                 FTSWReplacement({
            FTURLConnectionInstrumentation *instrumentation = [FTURLConnectionInstrumentation existingInstance];
            if (!instrumentation) {
                return FTSWCallOriginal(request, delegate, startImmediately);
            }
            FTURLConnectionHandler *initializingHandler = objc_getAssociatedObject(self, FTURLConnectionHandlerAssociationKey);
            if (initializingHandler && [instrumentation isPreparingHandler:initializingHandler]) {
                return FTSWCallOriginal(request, delegate, startImmediately);
            }
            FTURLConnectionPreparation *preparation;
            @try {
                preparation = [instrumentation prepareRequest:request delegate:delegate];
            } @catch (NSException *exception) {
                FTInnerLogError(@"NSURLConnection preparation exception: %@", exception);
            }
            if (!preparation) {
                FTURLConnectionHandler *nestedHandler = [instrumentation preparingHandlerForRequest:request];
                if (nestedHandler) {
                    [FTURLConnectionInstrumentation associateHandler:nestedHandler withConnection:self];
                }
                return FTSWCallOriginal(request, delegate, startImmediately);
            }
            [FTURLConnectionInstrumentation associateHandler:preparation.handler withConnection:self];
            if (startImmediately) {
                [preparation.handler recordStartWithDate:[instrumentation.clock date]
                                          continuousTime:[instrumentation.clock continuousTime]];
            }
            NSURLConnection *result;
            @try {
                result = FTSWCallOriginal(preparation.request, preparation.delegate, startImmediately);
                if (result) {
                    [FTURLConnectionInstrumentation associateHandler:preparation.handler withConnection:result];
                }
            } @catch (NSException *exception) {
                [preparation.handler discard];
                @throw;
            } @finally {
                [instrumentation finishPreparingHandler:preparation.handler];
            }
            if (result) {
                if (startImmediately) {
                    [instrumentation activateHandler:preparation.handler];
                }
            } else {
                [preparation.handler discard];
            }
            return result;
        }), FTSwizzlerModeOncePerClassAndSuperclasses, FTURLConnectionInitImmediateKey);

        FTSwizzlerInstanceMethod(NSURLConnection.class,
                                 @selector(start),
                                 FTSWReturnType(void),
                                 FTSWArguments(),
                                 FTSWReplacement({
            FTURLConnectionHandler *handler = objc_getAssociatedObject(self, FTURLConnectionHandlerAssociationKey);
            FTURLConnectionInstrumentation *instrumentation = handler.instrumentation;
            if (handler && [instrumentation isHandlerCurrent:handler]) {
                [handler recordStartWithDate:[instrumentation.clock date]
                              continuousTime:[instrumentation.clock continuousTime]];
            }
            FTSWCallOriginal();
            if (handler && [instrumentation isHandlerCurrent:handler] &&
                ![instrumentation isPreparingHandler:handler]) {
                [instrumentation activateHandler:handler];
            }
        }), FTSwizzlerModeOncePerClassAndSuperclasses, FTURLConnectionStartKey);

        FTSwizzlerInstanceMethod(NSURLConnection.class,
                                 @selector(cancel),
                                 FTSWReturnType(void),
                                 FTSWArguments(),
                                 FTSWReplacement({
            FTURLConnectionHandler *handler = objc_getAssociatedObject(self, FTURLConnectionHandlerAssociationKey);
            FTURLConnectionInstrumentation *instrumentation = handler.instrumentation;
            if (handler && [instrumentation isHandlerCurrent:handler]) {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [instrumentation handler:handler didReachTerminalWithResponse:nil error:error];
            }
            FTSWCallOriginal();
        }), FTSwizzlerModeOncePerClassAndSuperclasses, FTURLConnectionCancelKey);

        FTSwizzlerClassMethod(NSURLConnection.class,
                              @selector(connectionWithRequest:delegate:),
                              FTSWReturnType(NSURLConnection *),
                              FTSWArguments(NSURLRequest *request, id delegate),
                              FTSWReplacement({
            FTURLConnectionInstrumentation *instrumentation = [FTURLConnectionInstrumentation existingInstance];
            if (!instrumentation) {
                return FTSWCallOriginal(request, delegate);
            }
            FTURLConnectionPreparation *preparation;
            @try {
                preparation = [instrumentation prepareRequest:request delegate:delegate];
            } @catch (NSException *exception) {
                FTInnerLogError(@"NSURLConnection preparation exception: %@", exception);
            }
            if (!preparation) {
                return FTSWCallOriginal(request, delegate);
            }
            [preparation.handler recordStartWithDate:[instrumentation.clock date]
                                      continuousTime:[instrumentation.clock continuousTime]];
            NSURLConnection *result;
            @try {
                result = FTSWCallOriginal(preparation.request, preparation.delegate);
                if (result) {
                    [FTURLConnectionInstrumentation associateHandler:preparation.handler withConnection:result];
                }
            } @catch (NSException *exception) {
                [preparation.handler discard];
                @throw;
            } @finally {
                [instrumentation finishPreparingHandler:preparation.handler];
            }
            if (result) {
                [instrumentation activateHandler:preparation.handler];
            } else {
                [preparation.handler discard];
            }
            return result;
        }));

        FTSwizzlerClassMethod(NSURLConnection.class,
                              @selector(sendAsynchronousRequest:queue:completionHandler:),
                              FTSWReturnType(void),
                              FTSWArguments(NSURLRequest *request, NSOperationQueue *queue,
                                            FTURLConnectionCompletionHandler completionHandler),
                              FTSWReplacement({
            FTURLConnectionInstrumentation *instrumentation = [FTURLConnectionInstrumentation existingInstance];
            if (!instrumentation || !queue) {
                FTSWCallOriginal(request, queue, completionHandler);
                return;
            }
            FTURLConnectionPreparation *preparation;
            @try {
                preparation = [instrumentation prepareRequest:request delegate:nil];
            } @catch (NSException *exception) {
                FTInnerLogError(@"NSURLConnection preparation exception: %@", exception);
            }
            if (!preparation) {
                FTSWCallOriginal(request, queue, completionHandler);
                return;
            }
            // This API has one completion owner, not a delegate owner. Do not
            // bind Foundation's internal connections through the preparation registry.
            [instrumentation finishPreparingHandler:preparation.handler];
            [preparation.handler recordStartWithDate:[instrumentation.clock date]
                                      continuousTime:[instrumentation.clock continuousTime]];
            FTURLConnectionCompletionHandler originalCompletion = [completionHandler copy];
            FTURLConnectionCompletionHandler wrappedCompletion = ^(NSURLResponse *response, NSData *data, NSError *error) {
                if (data) {
                    [preparation.handler didReceiveData:data];
                }
                [instrumentation handler:preparation.handler didReachTerminalWithResponse:response error:error];
                if (originalCompletion) {
                    [queue addOperationWithBlock:^{
                        originalCompletion(response, data, error);
                    }];
                }
            };
            @try {
                FTSWCallOriginal(preparation.request, instrumentation.completionQueue, wrappedCompletion);
            } @catch (NSException *exception) {
                [preparation.handler discard];
                @throw;
            }
            [instrumentation activateHandler:preparation.handler];
        }));
#pragma clang diagnostic pop
    });
#endif
}

@end
