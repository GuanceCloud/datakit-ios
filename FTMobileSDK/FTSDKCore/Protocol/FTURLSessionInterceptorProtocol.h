//
//  FTURLSessionInterceptorProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/9/14.
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


#ifndef FTURLSessionInterceptorProtocol_h
#define FTURLSessionInterceptorProtocol_h
#import "FTRumResourceProtocol.h"
#import "FTTracerProtocol.h"
@class FTTraceContext;
NS_ASSUME_NONNULL_BEGIN
typedef BOOL(^FTIntakeUrl)( NSURL * _Nonnull url);
typedef BOOL(^FTResourceUrlHandler)( NSURL * _Nonnull url);
typedef NSDictionary<NSString *,id>* _Nullable (^ResourcePropertyProvider)( NSURLRequest * _Nullable request, NSURLResponse * _Nullable response,NSData *_Nullable data, NSError *_Nullable error);
/// Support custom trace, return TraceContext after confirming interception, return nil if not intercepted
typedef FTTraceContext*_Nullable(^TraceInterceptor)(NSURLRequest *_Nonnull request);
typedef BOOL (^SessionTaskErrorFilter)(NSError *_Nonnull error);

/// Session interception processing delegate
@protocol FTURLSessionInterceptorProtocol<NSObject>
@optional
/// User collection filter callback
@property (nonatomic, copy ,nullable) FTIntakeUrl intakeUrlHandler;
@property (nonatomic, copy ,nullable) FTResourceUrlHandler resourceUrlHandler;
@property (nonatomic, copy ,nullable) TraceInterceptor traceInterceptor;
@property (nonatomic, copy ,nullable) ResourcePropertyProvider resourcePropertyProvider;
@property (nonatomic, copy ,nullable) SessionTaskErrorFilter sessionTaskErrorFilter;


/// Collected resource data receiver object
@property (nonatomic, weak) id<FTRumResourceProtocol> rumResourceHandler;

- (void)setTracer:(id<FTTracerProtocol>)tracer;
/// Implement trace function, add trace parameters to request header
/// - Parameter request: http initial request
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request;

/// Implement trace function, add trace parameters to request header
/// - Parameter task: request task
- (void)traceInterceptTask:(NSURLSessionTask *)task;

/// Implement trace function, add trace parameters to request header
/// - Parameter traceInterceptor: trace interceptor
- (void)traceInterceptTask:(NSURLSessionTask *)task traceInterceptor:(nullable TraceInterceptor)traceInterceptor;

/// Request start -startResource
/// - Parameters:
///   - task: request task
- (void)interceptTask:(NSURLSessionTask *)task;

/// Collect request data information
/// - Parameters:
///   - task: request task
///   - metrics: request task data record
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0),macos(10.12));

/// Collect request data information
/// - Parameters:
///   - task: request task
///   - metrics: request task data record
///   - custom: whether it is a custom collected URLSession
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics custom:(BOOL)custom API_AVAILABLE(ios(10.0),macos(10.12));
/// Collect request return data
/// - Parameters:
///   - task: request task
///   - data: request return data
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data;
/// Request end -stopResource
/// - Parameters:
///   - task: request task
///   - error: error information
///
/// When passing to rum, first call -stopResource, then call -addResourceWithKey
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error;

/// Request end -stopResource
/// - Parameters:
///   - task: request task
///   - error: error information
///   - extraProvider: user custom additional information
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider errorFilter:(nullable SessionTaskErrorFilter)errorFilter;
@end
NS_ASSUME_NONNULL_END
#endif /* FTURLSessionInterceptorProtocol_h */
