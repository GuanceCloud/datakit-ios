//
//  FTURLConnectionHandler.h
//  FTMobileSDK
//

#import <Foundation/Foundation.h>
#import "FTURLSessionInterceptorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class FTURLConnectionInstrumentation;

typedef NS_ENUM(NSUInteger, FTURLConnectionHandlerState) {
    FTURLConnectionHandlerStatePrepared,
    FTURLConnectionHandlerStateStarted,
    FTURLConnectionHandlerStateTerminal,
};

/// Per-request state for NSURLConnection automatic Resource and Trace instrumentation.
NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.")
@interface FTURLConnectionHandler : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, assign, readonly) FTURLConnectionHandlerState state;
@property (nonatomic, copy, readonly) NSURLRequest *request;
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, NSString *> *injectedTraceHeaders;
@property (nonatomic, copy, readonly, nullable) NSString *traceID;
@property (nonatomic, copy, readonly, nullable) NSString *spanID;
@property (nonatomic, weak, nullable) FTURLConnectionInstrumentation *instrumentation;
@property (nonatomic, assign) NSUInteger generation;

- (instancetype)initWithRequest:(NSURLRequest *)request
                 resourceEnabled:(BOOL)resourceEnabled
                        provider:(nullable ResourcePropertyProvider)provider
                     errorFilter:(nullable SessionTaskErrorFilter)errorFilter
              rumResourceHandler:(nullable id<FTRumResourceProtocol>)rumResourceHandler;

- (BOOL)recordStartWithDate:(NSDate *)date continuousTime:(uint64_t)continuousTime;
- (void)activate;
- (void)discard;
- (void)didReceiveResponse:(NSURLResponse *)response;
- (void)didReceiveData:(NSData *)data;
- (void)didSendBodyDataWithTotalBytesWritten:(long long)totalBytesWritten;
- (void)updateRequest:(NSURLRequest *)request
               traceID:(nullable NSString *)traceID
                spanID:(nullable NSString *)spanID
  injectedTraceHeaders:(nullable NSDictionary<NSString *, NSString *> *)injectedTraceHeaders;
/// Atomically applies redirect security policy and updates the final Resource request snapshot.
- (NSURLRequest *)requestByPreparingRedirectRequest:(NSURLRequest *)request;
- (BOOL)recordTerminalWithResponse:(nullable NSURLResponse *)response
                              error:(nullable NSError *)error
                               date:(NSDate *)date
                     continuousTime:(uint64_t)continuousTime;

/// These methods are called only from the instrumentation processing queue.
- (void)reportStartIfNeeded;
- (void)reportTerminalIfNeeded;

@end

NS_ASSUME_NONNULL_END
