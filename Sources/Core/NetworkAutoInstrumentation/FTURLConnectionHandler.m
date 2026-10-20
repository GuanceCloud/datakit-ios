//
//  FTURLConnectionHandler.m
//  FTMobileSDK
//

#import "FTURLConnectionHandler.h"
#import "FTResourceContentModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"
#import "NSDictionary+FTCopyProperties.h"
#import "FTInnerLog.h"
#import <limits.h>

FOUNDATION_EXPORT NSString * const FTURLConnectionRequestOwnerPropertyKey;

static const NSUInteger FTURLConnectionMaximumBufferedBodySize = 512 * 1024;

static BOOL FTURLConnectionURLsHaveSameOrigin(NSURL *left, NSURL *right) {
    if (!left || !right) {
        return NO;
    }
    NSString *leftScheme = left.scheme.lowercaseString ?: @"";
    NSString *rightScheme = right.scheme.lowercaseString ?: @"";
    NSString *leftHost = left.host.lowercaseString ?: @"";
    NSString *rightHost = right.host.lowercaseString ?: @"";
    NSNumber *leftPort = left.port ?: ([leftScheme isEqualToString:@"https"] ? @443 : @80);
    NSNumber *rightPort = right.port ?: ([rightScheme isEqualToString:@"https"] ? @443 : @80);
    return [leftScheme isEqualToString:rightScheme] &&
           [leftHost isEqualToString:rightHost] &&
           [leftPort isEqualToNumber:rightPort];
}

@interface FTURLConnectionHandler ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, assign, readwrite) FTURLConnectionHandlerState state;
@property (nonatomic, copy, readwrite) NSURLRequest *request;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *injectedTraceHeaders;
@property (nonatomic, copy, readwrite) NSString *traceID;
@property (nonatomic, copy, readwrite) NSString *spanID;
@property (nonatomic, assign) BOOL resourceEnabled;
@property (nonatomic, copy) ResourcePropertyProvider provider;
@property (nonatomic, copy) SessionTaskErrorFilter errorFilter;
@property (nonatomic, weak) id<FTRumResourceProtocol> rumResourceHandler;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableData *bufferedData;
@property (nonatomic, assign) BOOL responseBufferOverflow;
@property (nonatomic, assign) unsigned long long responseBodyBytes;
@property (nonatomic, strong) NSNumber *requestBodyBytes;
@property (nonatomic, assign) BOOL uploadProgressObserved;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSDate *terminalDate;
@property (nonatomic, assign) long long startEpochNanoseconds;
@property (nonatomic, assign) uint64_t startContinuousTime;
@property (nonatomic, assign) uint64_t terminalContinuousTime;
@property (nonatomic, assign) BOOL activated;
@property (nonatomic, assign) BOOL startReported;
@property (nonatomic, assign) BOOL terminalReported;
@end

@implementation FTURLConnectionHandler

- (instancetype)initWithRequest:(NSURLRequest *)request
                 resourceEnabled:(BOOL)resourceEnabled
                        provider:(ResourcePropertyProvider)provider
                     errorFilter:(SessionTaskErrorFilter)errorFilter
              rumResourceHandler:(id<FTRumResourceProtocol>)rumResourceHandler {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _identifier = [FTBaseInfoHandler randomUUID];
        _state = FTURLConnectionHandlerStatePrepared;
        _request = [request copy];
        _resourceEnabled = resourceEnabled;
        _provider = [provider copy];
        _errorFilter = [errorFilter copy];
        _rumResourceHandler = rumResourceHandler;
        [self updateRequestBodyFallbackLocked:request];
    }
    return self;
}

- (void)updateRequestBodyFallbackLocked:(NSURLRequest *)request {
    if (self.uploadProgressObserved) {
        return;
    }
    NSData *body = request.HTTPBody;
    if (body) {
        self.requestBodyBytes = @(body.length);
    } else if (!request.HTTPBodyStream) {
        self.requestBodyBytes = @0;
    } else {
        self.requestBodyBytes = nil;
    }
}

- (BOOL)recordStartWithDate:(NSDate *)date continuousTime:(uint64_t)continuousTime {
    [self.lock lock];
    BOOL changed = NO;
    if (self.state == FTURLConnectionHandlerStatePrepared) {
        self.state = FTURLConnectionHandlerStateStarted;
        self.startDate = date;
        self.startEpochNanoseconds = [date ft_nanosecondTimeStamp];
        self.startContinuousTime = continuousTime;
        changed = YES;
    }
    [self.lock unlock];
    return changed;
}

- (void)activate {
    [self.lock lock];
    self.activated = YES;
    [self.lock unlock];
}

- (void)discard {
    [self.lock lock];
    self.activated = NO;
    self.resourceEnabled = NO;
    self.state = FTURLConnectionHandlerStateTerminal;
    [self.lock unlock];
}

- (void)didReceiveResponse:(NSURLResponse *)response {
    [self.lock lock];
    if (self.state != FTURLConnectionHandlerStateTerminal) {
        self.response = response;
    }
    [self.lock unlock];
}

- (void)didReceiveData:(NSData *)data {
    if (!data) {
        return;
    }
    [self.lock lock];
    if (self.state == FTURLConnectionHandlerStateStarted) {
        if (ULLONG_MAX - self.responseBodyBytes < data.length) {
            self.responseBodyBytes = ULLONG_MAX;
        } else {
            self.responseBodyBytes += data.length;
        }
        if (self.provider && !self.responseBufferOverflow && data.length > 0) {
            NSUInteger bufferedLength = self.bufferedData.length;
            if (bufferedLength > FTURLConnectionMaximumBufferedBodySize ||
                data.length > FTURLConnectionMaximumBufferedBodySize - bufferedLength) {
                self.bufferedData = nil;
                self.responseBufferOverflow = YES;
            } else if (self.bufferedData) {
                [self.bufferedData appendData:data];
            } else {
                self.bufferedData = [NSMutableData dataWithData:data];
            }
        }
    }
    [self.lock unlock];
}

- (void)didSendBodyDataWithTotalBytesWritten:(long long)totalBytesWritten {
    if (totalBytesWritten < 0) {
        return;
    }
    [self.lock lock];
    if (self.state == FTURLConnectionHandlerStateStarted) {
        long long current = self.uploadProgressObserved ? self.requestBodyBytes.longLongValue : 0;
        self.uploadProgressObserved = YES;
        self.requestBodyBytes = @(MAX(current, totalBytesWritten));
    }
    [self.lock unlock];
}

- (void)updateRequest:(NSURLRequest *)request
               traceID:(NSString *)traceID
                spanID:(NSString *)spanID
  injectedTraceHeaders:(NSDictionary<NSString *,NSString *> *)injectedTraceHeaders {
    if (!request) {
        return;
    }
    [self.lock lock];
    if (self.state != FTURLConnectionHandlerStateTerminal) {
        self.request = [request copy];
        self.traceID = [traceID copy];
        self.spanID = [spanID copy];
        self.injectedTraceHeaders = [injectedTraceHeaders copy];
        [self updateRequestBodyFallbackLocked:request];
    }
    [self.lock unlock];
}

- (NSURLRequest *)requestByPreparingRedirectRequest:(NSURLRequest *)request {
    if (!request) {
        return request;
    }
    [self.lock lock];
    if (self.state == FTURLConnectionHandlerStateTerminal) {
        [self.lock unlock];
        return request;
    }
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    NSDictionary<NSString *, NSString *> *retainedInjectedHeaders = self.injectedTraceHeaders;
    NSString *traceID = self.traceID;
    NSString *spanID = self.spanID;
    if (!FTURLConnectionURLsHaveSameOrigin(self.request.URL, request.URL)) {
        [retainedInjectedHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            if ([[mutableRequest valueForHTTPHeaderField:key] isEqualToString:value]) {
                [mutableRequest setValue:nil forHTTPHeaderField:key];
            }
        }];
        retainedInjectedHeaders = nil;
        traceID = nil;
        spanID = nil;
    } else if (retainedInjectedHeaders.count > 0) {
        __block BOOL allRetained = YES;
        [retainedInjectedHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            if (![[mutableRequest valueForHTTPHeaderField:key] isEqualToString:value]) {
                allRetained = NO;
                *stop = YES;
            }
        }];
        if (!allRetained) {
            retainedInjectedHeaders = nil;
            traceID = nil;
            spanID = nil;
        }
    }
    [NSURLProtocol setProperty:self.identifier forKey:FTURLConnectionRequestOwnerPropertyKey inRequest:mutableRequest];
    NSURLRequest *effectiveRequest = [mutableRequest copy];
    self.request = effectiveRequest;
    self.traceID = traceID;
    self.spanID = spanID;
    self.injectedTraceHeaders = retainedInjectedHeaders;
    [self updateRequestBodyFallbackLocked:effectiveRequest];
    [self.lock unlock];
    return effectiveRequest;
}

- (BOOL)recordTerminalWithResponse:(NSURLResponse *)response
                              error:(NSError *)error
                               date:(NSDate *)date
                     continuousTime:(uint64_t)continuousTime {
    [self.lock lock];
    BOOL changed = NO;
    if (self.state != FTURLConnectionHandlerStateTerminal) {
        self.state = FTURLConnectionHandlerStateTerminal;
        if (response) {
            self.response = response;
        }
        self.error = error;
        self.terminalDate = date;
        self.terminalContinuousTime = continuousTime;
        changed = YES;
    }
    [self.lock unlock];
    return changed;
}

- (void)reportStartIfNeeded {
    [self.lock lock];
    if (!self.activated || !self.resourceEnabled || !self.startDate || self.startReported) {
        [self.lock unlock];
        return;
    }
    self.startReported = YES;
    NSString *identifier = [self.identifier copy];
    NSDate *startDate = self.startDate;
    id<FTRumResourceProtocol> handler = self.rumResourceHandler;
    [self.lock unlock];

    if ([handler respondsToSelector:@selector(startResourceWithKey:property:time:)]) {
        [handler startResourceWithKey:identifier property:nil time:startDate];
    } else {
        [handler startResourceWithKey:identifier property:nil];
    }
}

- (void)reportTerminalIfNeeded {
    [self reportStartIfNeeded];

    [self.lock lock];
    if (!self.activated || !self.resourceEnabled || !self.startReported ||
        self.state != FTURLConnectionHandlerStateTerminal || self.terminalReported) {
        [self.lock unlock];
        return;
    }
    self.terminalReported = YES;
    NSString *identifier = [self.identifier copy];
    NSURLRequest *request = [self.request copy];
    NSURLResponse *response = self.response;
    NSError *error = self.error;
    NSData *data = self.responseBufferOverflow ? nil : [self.bufferedData copy];
    NSNumber *requestBodyBytes = self.requestBodyBytes;
    NSNumber *responseBodyBytes = @(self.responseBodyBytes);
    NSDate *terminalDate = self.terminalDate;
    long long startEpochNanoseconds = self.startEpochNanoseconds;
    uint64_t startContinuousTime = self.startContinuousTime;
    uint64_t terminalContinuousTime = self.terminalContinuousTime;
    NSString *traceID = [self.traceID copy];
    NSString *spanID = [self.spanID copy];
    ResourcePropertyProvider provider = [self.provider copy];
    SessionTaskErrorFilter errorFilter = [self.errorFilter copy];
    id<FTRumResourceProtocol> rumHandler = self.rumResourceHandler;
    [self.lock unlock];

    @try {
        if (error && errorFilter && errorFilter(error)) {
            error = nil;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }

    NSDictionary *property = nil;
    @try {
        if (provider) {
            property = [provider(request, response, data, error) ft_deepCopy];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@", exception);
    }

    FTResourceMetricsModel *metrics = [[FTResourceMetricsModel alloc] init];
    metrics.fetchStartNsTimeInterval = startEpochNanoseconds;
    uint64_t duration = terminalContinuousTime >= startContinuousTime ?
        terminalContinuousTime - startContinuousTime : 0;
    if (duration > (uint64_t)LLONG_MAX || startEpochNanoseconds > LLONG_MAX - (long long)duration) {
        metrics.fetchEndNsTimeInterval = LLONG_MAX;
    } else {
        metrics.fetchEndNsTimeInterval = startEpochNanoseconds + (long long)duration;
    }
    metrics.responseSize = responseBodyBytes;
    metrics.requestSize = requestBodyBytes;
    metrics.disableHeaderSizeFallback = YES;
    metrics.connectionReuseUnavailable = YES;

    FTResourceContentModel *content = [[FTResourceContentModel alloc] initWithRequest:request
                                                                            response:response
                                                                                data:data
                                                                               error:error];
    if ([rumHandler respondsToSelector:@selector(stopResourceWithKey:property:time:)]) {
        [rumHandler stopResourceWithKey:identifier property:property time:terminalDate];
    } else {
        [rumHandler stopResourceWithKey:identifier property:property];
    }
    if ([rumHandler respondsToSelector:@selector(addResourceWithKey:metrics:content:spanID:traceID:)]) {
        [rumHandler addResourceWithKey:identifier metrics:metrics content:content spanID:spanID traceID:traceID];
    } else {
        [rumHandler addResourceWithKey:identifier metrics:metrics content:content];
    }
}

@end
