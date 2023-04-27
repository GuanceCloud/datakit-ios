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
NS_ASSUME_NONNULL_BEGIN
typedef BOOL(^FTIntakeUrl)(NSURL *url);

/// session 拦截处理代理
@protocol FTURLSessionInterceptorDelegate<NSObject>
@required
/// 设置需要屏蔽的内部链接
@property (nonatomic, copy) NSString *innerUrl;
/// 用户采集过滤回调
@property (nonatomic, copy ,nullable) FTIntakeUrl intakeUrlHandler;
@optional
/// 采集的 resource 数据接收对象
@property (nonatomic, weak) id<FTRumResourceProtocol> innerResourceHandeler;
/// 设置是否支持自动采集 rum resource 数据
@property (nonatomic, assign) BOOL enableAutoRumTrack;

/// 实现 trace 功能，给 request header 添加 trace 参数
/// - Parameter request: http 初始请求
- (NSURLRequest *)injectTraceHeader:(NSURLRequest *)request;

/// 请求开始 -startResource
/// - Parameters:
///   - task: 请求任务
///   - session: session
- (void)taskCreated:(NSURLSessionTask *)task  session:(NSURLSession *)session;

/// 收集请求的数据信息
/// - Parameters:
///   - task: 请求任务
///   - metrics: 请求任务的数据记录
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0),macos(10.12));
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
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error;

@end
NS_ASSUME_NONNULL_END
#endif /* FTURLSessionInterceptorProtocol_h */
