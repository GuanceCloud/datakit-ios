//
//  FTURLConnectionInstrumentation.h
//  FTMobileSDK
//

#import <Foundation/Foundation.h>
#import "FTURLSessionInterceptorProtocol.h"
#import "FTInternalConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class FTURLConnectionHandler;

FOUNDATION_EXPORT NSString * const FTURLConnectionRequestOwnerPropertyKey;
/// Passive request-metadata lookup used by NSURLSession instrumentation as well.
/// This helper does not install or invoke NSURLConnection instrumentation.
FOUNDATION_EXPORT BOOL FTRequestIsOwnedByURLConnection(NSURLRequest *request);

NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.")
@protocol FTURLConnectionClock <NSObject>
- (NSDate *)date;
- (uint64_t)continuousTime;
@end

/// Automatic RUM Resource and Trace instrumentation for NSURLConnection.
NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.")
@interface FTURLConnectionInstrumentation : NSObject

@property (atomic, assign, readonly) BOOL shouldTraceInterceptor;
@property (atomic, assign, readonly) BOOL shouldRUMInterceptor;

+ (instancetype)sharedInstance;
+ (nullable instancetype)existingInstance;

/// Internal connection-owned context; never creates an instrumentation instance.
+ (nullable FTURLConnectionHandler *)handlerForConnection:(nullable NSURLConnection *)connection;
+ (void)associateHandler:(FTURLConnectionHandler *)handler withConnection:(NSURLConnection *)connection;

- (void)setEnableAutoRumResource:(BOOL)enabled
              resourceUrlHandler:(nullable FTResourceUrlHandler)resourceUrlHandler
        resourcePropertyProvider:(nullable ResourcePropertyProvider)resourcePropertyProvider
          sessionTaskErrorFilter:(nullable SessionTaskErrorFilter)sessionTaskErrorFilter;
- (void)setTraceEnableAutoTrace:(BOOL)enabled
              enableLinkRumData:(BOOL)enableLinkRumData
                     sampleRate:(int)sampleRate
                      traceType:(NetworkTraceType)traceType
               traceInterceptor:(nullable TraceInterceptor)traceInterceptor
                    serviceName:(NSString *)serviceName;
- (void)updateTraceSampleRate:(int)sampleRate;
- (void)updateResourceEnabled:(BOOL)enabled;
- (void)updateTraceEnabled:(BOOL)enabled;
- (void)setRumResourceHandler:(nullable id<FTRumResourceProtocol>)handler;
- (void)setIntakeUrlHandler:(nullable FTIntakeUrl)intakeUrlHandler;

/// Delegate observer entry points. They capture time before queueing any work.
- (void)handler:(FTURLConnectionHandler *)handler
didReachTerminalWithResponse:(nullable NSURLResponse *)response
          error:(nullable NSError *)error;
- (nullable NSURLRequest *)handler:(FTURLConnectionHandler *)handler
                 redirectedRequest:(NSURLRequest *)request
                           response:(nullable NSURLResponse *)response;

- (void)syncProcess;
- (void)shutDown;

@end

NS_ASSUME_NONNULL_END
