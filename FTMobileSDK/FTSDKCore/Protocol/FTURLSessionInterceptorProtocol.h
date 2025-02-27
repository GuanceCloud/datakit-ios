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
/// 支持自定义 trace, 确认拦截后，返回 TraceContext，不拦截返回 nil
typedef FTTraceContext*_Nullable(^TraceInterceptor)(NSURLRequest *_Nonnull request);

/// session 拦截处理代理
@protocol FTURLSessionInterceptorProtocol<NSObject>
@optional
/// 用户采集过滤回调
@property (nonatomic, copy ,nullable) FTIntakeUrl intakeUrlHandler;
@property (nonatomic, copy ,nullable) FTResourceUrlHandler resourceUrlHandler;
@property (nonatomic, copy ,nullable) TraceInterceptor traceInterceptor;
@property (nonatomic, copy ,nullable) ResourcePropertyProvider resourcePropertyProvider;


/// 采集的 resource 数据接收对象
@property (nonatomic, weak) id<FTRumResourceProtocol> rumResourceHandler;

- (void)setTracer:(id<FTTracerProtocol>)tracer;
/// 实现 trace 功能，给 request header 添加 trace 参数
/// - Parameter request: http 初始请求
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request;

/// 实现 trace 功能，给 request header 添加 trace 参数
/// - Parameter task: 请求任务
- (void)traceInterceptTask:(NSURLSessionTask *)task;

/// 实现 trace 功能，给 request header 添加 trace 参数
/// - Parameter traceInterceptor: trace 拦截器
- (void)traceInterceptTask:(NSURLSessionTask *)task traceInterceptor:(nullable TraceInterceptor)traceInterceptor;

/// 请求开始 -startResource
/// - Parameters:
///   - task: 请求任务
- (void)interceptTask:(NSURLSessionTask *)task;

/// 收集请求的数据信息
/// - Parameters:
///   - task: 请求任务
///   - metrics: 请求任务的数据记录
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0),macos(10.12));

/// 收集请求的数据信息
/// - Parameters:
///   - task: 请求任务
///   - metrics: 请求任务的数据记录
///   - custom: 是否是自定义采集的 URLSession
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics custom:(BOOL)custom API_AVAILABLE(ios(10.0),macos(10.12));
/// 收集请求的返回数据
/// - Parameters:
///   - task: 请求任务
///   - data: 请求的返回数据
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data;
/// 请求结束 -stopResource
/// - Parameters:
///   - task: 请求任务
///   - error: error 信息
///
/// 传入 rum 时，先调用 -stopResource，再调用 -addResourceWithKey
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error ;

/// 请求结束 -stopResource
/// - Parameters:
///   - task: 请求任务
///   - error: error 信息
///   - extraProvider: 用户自定义额外信息
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider;
@end
NS_ASSUME_NONNULL_END
#endif /* FTURLSessionInterceptorProtocol_h */
