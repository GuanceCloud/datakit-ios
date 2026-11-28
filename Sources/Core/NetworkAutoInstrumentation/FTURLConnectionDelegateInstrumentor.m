//
//  FTURLConnectionDelegateInstrumentor.m
//  FTMobileSDK
//

#import "FTURLConnectionDelegateInstrumentor.h"
#import "FTURLConnectionDelegate.h"
#import "FTSwizzler.h"
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Stack-local scopes distinguish superclass calls from callbacks for another
// connection on the same delegate. They never retain application objects.
typedef struct FTURLConnectionCallbackScope {
    void *delegate;
    void *connection;
    SEL selector;
    BOOL observed;
    struct FTURLConnectionCallbackScope *previous;
} FTURLConnectionCallbackScope;

static __thread FTURLConnectionCallbackScope *currentCallbackScope;
static char callbackKeys[6];

static BOOL EnterCallback(FTURLConnectionCallbackScope *scope, id delegate, id connection, SEL selector) {
    scope->delegate = (__bridge void *)delegate;
    scope->connection = (__bridge void *)connection;
    scope->selector = selector;
    scope->observed = NO;
    scope->previous = currentCallbackScope;
    BOOL outermost = YES;
    for (FTURLConnectionCallbackScope *entry = currentCallbackScope; entry; entry = entry->previous) {
        if (entry->delegate == scope->delegate && entry->connection == scope->connection && entry->selector == selector) {
            outermost = NO;
            break;
        }
    }
    currentCallbackScope = scope;
    return outermost;
}

@implementation FTURLConnectionDelegateInstrumentor

+ (BOOL)shouldObserveDelegate:(id)delegate connection:(NSURLConnection *)connection selector:(SEL)selector {
    FTURLConnectionCallbackScope *outermost = NULL;
    for (FTURLConnectionCallbackScope *entry = currentCallbackScope; entry; entry = entry->previous) {
        if (entry->delegate == (__bridge void *)delegate && entry->connection == (__bridge void *)connection &&
            entry->selector == selector) {
            outermost = entry;
        }
    }
    if (!outermost) {
        return YES; // Explicit default delegate.
    }
    if (outermost->observed) {
        return NO;
    }
    outermost->observed = YES;
    return YES;
}

+ (void)hookSelector:(SEL)selector inClass:(Class)delegateClass key:(const void *)key {
    IMP observer = method_getImplementation(class_getInstanceMethod(FTURLConnectionDelegate.class, selector));
    Method method = class_getInstanceMethod(delegateClass, selector);
    if (!method || method_getImplementation(method) == observer) {
        return; // Default observer methods already collect without a wrapper.
    }
    if (selector == @selector(connection:willSendRequest:redirectResponse:)) {
        FTSwizzlerInstanceMethod(delegateClass, selector, FTSWReturnType(NSURLRequest *),
                                 FTSWArguments(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *response),
                                 FTSWReplacement({
            FTURLConnectionCallbackScope scope;
            BOOL outermost = EnterCallback(&scope, self, connection, selector_);
            @try {
                NSURLRequest *result = FTSWCallOriginal(connection, request, response);
                if (outermost && result) {
                    result = ((NSURLRequest *(*)(id, SEL, NSURLConnection *, NSURLRequest *, NSURLResponse *))observer)
                        (self, selector_, connection, result, response);
                }
                return result;
            } @finally {
                currentCallbackScope = scope.previous;
            }
        }), FTSwizzlerModeOncePerClass, key);
    } else if (selector == @selector(connection:didReceiveData:)) {
        FTSwizzlerInstanceMethod(delegateClass, selector, FTSWReturnType(void),
                                 FTSWArguments(NSURLConnection *connection, NSData *data),
                                 FTSWReplacement({
            FTURLConnectionCallbackScope scope;
            BOOL outermost = EnterCallback(&scope, self, connection, selector_);
            @try {
                if (outermost) {
                    ((void (*)(id, SEL, NSURLConnection *, NSData *))observer)(self, selector_, connection, data);
                }
                FTSWCallOriginal(connection, data);
            } @finally {
                currentCallbackScope = scope.previous;
            }
        }), FTSwizzlerModeOncePerClass, key);
    } else if (selector == @selector(connection:didReceiveResponse:)) {
        FTSwizzlerInstanceMethod(delegateClass, selector, FTSWReturnType(void),
                                 FTSWArguments(NSURLConnection *connection, NSURLResponse *response),
                                 FTSWReplacement({
            FTURLConnectionCallbackScope scope;
            BOOL outermost = EnterCallback(&scope, self, connection, selector_);
            @try {
                if (outermost) {
                    ((void (*)(id, SEL, NSURLConnection *, NSURLResponse *))observer)(self, selector_, connection, response);
                }
                FTSWCallOriginal(connection, response);
            } @finally {
                currentCallbackScope = scope.previous;
            }
        }), FTSwizzlerModeOncePerClass, key);
    } else if (selector == @selector(connection:didFailWithError:)) {
        FTSwizzlerInstanceMethod(delegateClass, selector, FTSWReturnType(void),
                                 FTSWArguments(NSURLConnection *connection, NSError *error),
                                 FTSWReplacement({
            FTURLConnectionCallbackScope scope;
            BOOL outermost = EnterCallback(&scope, self, connection, selector_);
            @try {
                if (outermost) {
                    ((void (*)(id, SEL, NSURLConnection *, NSError *))observer)(self, selector_, connection, error);
                }
                FTSWCallOriginal(connection, error);
            } @finally {
                currentCallbackScope = scope.previous;
            }
        }), FTSwizzlerModeOncePerClass, key);
    } else if (selector == @selector(connectionDidFinishLoading:)) {
        FTSwizzlerInstanceMethod(delegateClass, selector, FTSWReturnType(void),
                                 FTSWArguments(NSURLConnection *connection),
                                 FTSWReplacement({
            FTURLConnectionCallbackScope scope;
            BOOL outermost = EnterCallback(&scope, self, connection, selector_);
            @try {
                if (outermost) {
                    ((void (*)(id, SEL, NSURLConnection *))observer)(self, selector_, connection);
                }
                FTSWCallOriginal(connection);
            } @finally {
                currentCallbackScope = scope.previous;
            }
        }), FTSwizzlerModeOncePerClass, key);
    } else {
        FTSwizzlerInstanceMethod(delegateClass, selector, FTSWReturnType(void),
                                 FTSWArguments(NSURLConnection *connection, NSInteger bytes, NSInteger total, NSInteger expected),
                                 FTSWReplacement({
            FTURLConnectionCallbackScope scope;
            BOOL outermost = EnterCallback(&scope, self, connection, selector_);
            @try {
                if (outermost) {
                    ((void (*)(id, SEL, NSURLConnection *, NSInteger, NSInteger, NSInteger))observer)
                        (self, selector_, connection, bytes, total, expected);
                }
                FTSWCallOriginal(connection, bytes, total, expected);
            } @finally {
                currentCallbackScope = scope.previous;
            }
        }), FTSwizzlerModeOncePerClass, key);
    }
}

// Match URLSession's signature-correct no-op installation, except that a
// redirect default must return the proposed request instead of cancelling it.
+ (IMP)defaultImplementationForSelector:(SEL)selector {
    if (selector == @selector(connection:willSendRequest:redirectResponse:)) {
        return imp_implementationWithBlock(^NSURLRequest *(__unused id delegate, __unused NSURLConnection *connection,
                                                          NSURLRequest *request, __unused NSURLResponse *response) {
            return request;
        });
    }
    if (selector == @selector(connection:didFailWithError:)) {
        return imp_implementationWithBlock(^(__unused id delegate, __unused NSURLConnection *connection, __unused NSError *error) {});
    }
    if (selector == @selector(connection:didReceiveResponse:)) {
        return imp_implementationWithBlock(^(__unused id delegate, __unused NSURLConnection *connection, __unused NSURLResponse *response) {});
    }
    if (selector == @selector(connection:didReceiveData:)) {
        return imp_implementationWithBlock(^(__unused id delegate, __unused NSURLConnection *connection, __unused NSData *data) {});
    }
    if (selector == @selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:)) {
        return imp_implementationWithBlock(^(__unused id delegate, __unused NSURLConnection *connection,
                                            __unused NSInteger bytes, __unused NSInteger total, __unused NSInteger expected) {});
    }
    if (selector == @selector(connectionDidFinishLoading:)) {
        return imp_implementationWithBlock(^(__unused id delegate, __unused NSURLConnection *connection) {});
    }
    return NULL;
}

+ (BOOL)addDefaultMethodIfNeededToClass:(Class)delegateClass selector:(SEL)selector {
    if (class_getInstanceMethod(delegateClass, selector)) {
        return YES; // Preserve inherited and dynamically resolved methods too.
    }
    Method signature = class_getInstanceMethod(FTURLConnectionDelegate.class, selector);
    if (!signature) {
        return NO;
    }
    IMP implementation = [self defaultImplementationForSelector:selector];
    if (!implementation) {
        return NO;
    }
    if (!class_addMethod(delegateClass, selector, implementation, method_getTypeEncoding(signature))) {
        // Another installer may have won the race. Do not overwrite its IMP.
        imp_removeBlock(implementation);
        return class_getInstanceMethod(delegateClass, selector) != NULL;
    }
    return YES;
}

+ (BOOL)instrumentDelegate:(id)delegate {
    if (!delegate) {
        return NO;
    }
    if ([delegate isKindOfClass:FTURLConnectionDelegate.class]) {
        return YES;
    }
    // Do not change proxy resolution or the data-vs-file-download contract.
    if ([delegate isProxy] || [delegate respondsToSelector:@selector(connectionDidFinishDownloading:destinationURL:)]) {
        return NO;
    }
    SEL selectors[] = {
        @selector(connection:didFailWithError:),
        @selector(connection:willSendRequest:redirectResponse:),
        @selector(connection:didReceiveResponse:),
        @selector(connection:didReceiveData:),
        @selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:),
        @selector(connectionDidFinishLoading:)
    };
    @synchronized (self) {
        Class actualClass = object_getClass(delegate);
        if (!actualClass || class_isMetaClass(actualClass) || !class_getSuperclass(actualClass)) {
            return NO; // Never make all NSObject/NSProxy instances observers.
        }
        // Complete the compatibility check before changing any method table.
        for (NSUInteger index = 0; index < 6; index++) {
            if (!class_getInstanceMethod(actualClass, selectors[index])) {
                if ([delegate respondsToSelector:selectors[index]] ||
                    [delegate forwardingTargetForSelector:selectors[index]]) {
                    return NO; // Do not shadow an application's forwarding path.
                }
            }
        }
        for (NSUInteger index = 0; index < 6; index++) {
            if (![self addDefaultMethodIfNeededToClass:actualClass selector:selectors[index]]) {
                return NO;
            }
        }
        // Like URLSession, defaults and business methods use one hook path.
        // Per-class keys protect repeat registration; callback scopes separately
        // prevent duplicate observation through a parent/child call chain.
        for (NSUInteger index = 0; index < 6; index++) {
            [self hookSelector:selectors[index] inClass:actualClass key:&callbackKeys[index]];
        }
        return YES;
    }
}

@end

#pragma clang diagnostic pop
