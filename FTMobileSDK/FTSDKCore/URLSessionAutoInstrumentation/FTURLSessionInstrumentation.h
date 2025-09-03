//
//  URLSessionAutoInstrumentation.h
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


#import <Foundation/Foundation.h>
#import "FTURLSessionInterceptorProtocol.h"
#import "FTTracerProtocol.h"
#import "FTExternalResourceProtocol.h"
#import "FTTraceContext.h"
NS_ASSUME_NONNULL_BEGIN
typedef enum FTNetworkTraceType:NSUInteger FTNetworkTraceType;
/// URLSession automation object for collecting rum data and implementing trace functionality
@interface FTURLSessionInstrumentation : NSObject<NSURLSessionDelegate>

/// Session interception handler for processing resource link tracing (trace) and rum resource data collection
@property (nonatomic, weak ,readonly) id<FTURLSessionInterceptorProtocol> interceptor;
/// Object provided to external for handling user-defined resource data
@property (nonatomic, weak ,readonly) id<FTExternalResourceProtocol> externalResourceHandler;

/// Determine whether automatic link tracing is allowed
@property (atomic, assign, readonly) BOOL shouldTraceInterceptor;

/// Determine whether automatic RUM collection is allowed
@property (atomic, assign, readonly) BOOL shouldRUMInterceptor;


- (BOOL)isNotSDKInsideUrl:(NSURL *)url;

- (instancetype)init NS_UNAVAILABLE;

/// Singleton
+ (instancetype)sharedInstance;

/// Set whether to automatically collect RUM Resource
/// - Parameter enableAutoRumTrack: Whether to automatically collect
- (void)setEnableAutoRumTrace:(BOOL)enableAutoRumTrack
           resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler
     resourcePropertyProvider:(ResourcePropertyProvider)resourcePropertyProvider
       sessionTaskErrorFilter:(SessionTaskErrorFilter)sessionTaskErrorFilter;

/// Set trace configuration options, enable trace
/// - Parameters:
///   - enableAutoTrace: Whether to enable automatic link tracing
///   - enableLinkRumData: Whether to associate with RUM
///   - sampleRate: Sampling rate
///   - traceType: Link type
- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace
              enableLinkRumData:(BOOL)enableLinkRumData
                     sampleRate:(int)sampleRate
                      traceType:(FTNetworkTraceType)traceType
               traceInterceptor:(TraceInterceptor)traceInterceptor;
/// Set SDK internal data upload URL
/// - Parameters
///   - sdkUrlStr: SDK internal data upload URL
///   - serviceName:
- (void)setSdkUrlStr:(NSString *)sdkUrlStr serviceName:(NSString *)serviceName;

/// Set RUM resource data processing object that conforms to FTRumResourceProtocol
///
/// HTTP resource data collected by this module should be passed to the RUM module
/// - Parameter handler: RUM module data receiving object
- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler;

/// Set URL filtering
/// - Parameter intakeUrlHandler: Callback to determine whether to collect, return YES to collect, NO to filter out
- (void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler;

- (void)enableSessionDelegate:(id <NSURLSessionDelegate>)delegate;
- (nullable id<FTURLSessionInterceptorProtocol>)traceInterceptor:(id<NSURLSessionDelegate>)delegate;
- (nullable id<FTURLSessionInterceptorProtocol>)rumInterceptor:(id<NSURLSessionDelegate>)delegate;
/// Shut down
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
