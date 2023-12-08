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
NS_ASSUME_NONNULL_BEGIN
typedef enum FTNetworkTraceType:NSUInteger FTNetworkTraceType;
///  url session 自动化 采集 rum 数据，实现 trace 功能的对象
@interface FTURLSessionInstrumentation : NSObject

/// session 拦截处理对象 处理 resource 的链路追踪（trace）rum resource数据采集
@property (nonatomic, weak ,readonly) id<FTURLSessionInterceptorProtocol> interceptor;
/// 向外部提供处理用户自定义 resource 数据的对象
@property (nonatomic, weak ,readonly) id<FTExternalResourceProtocol> externalResourceHandler;

@property (atomic, assign, readonly) BOOL shouldInterceptor;

- (BOOL)isNotSDKInsideUrl:(NSURL *)url;
/// 单例
+ (instancetype)sharedInstance;

/// 设置是否自动采集 RUM Resource
/// - Parameter enableAutoRumTrack: 是否自动采集
- (void)setEnableAutoRumTrack:(BOOL)enableAutoRumTrack resourceUrlHandler:(FTResourceUrlHandler)resourceUrlHandler;

/// 设置 trace 配置项，开启 trace
/// - Parameters:
///   - enableAutoTrace: 是否开启自动链路追踪
///   - enableLinkRumData: 是否关联 RUM
///   - sampleRate: 采样率
///   - traceType: 链路类型
- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace enableLinkRumData:(BOOL)enableLinkRumData sampleRate:(int)sampleRate traceType:(FTNetworkTraceType)traceType;
/// 设置 sdk 内部的数据上传 url
/// - Parameter sdkUrlStr: sdk 内部的数据上传 url
- (void)setSdkUrlStr:(NSString *)sdkUrlStr;

/// 设置遵循 FTRumResourceProtocol 的 rum resource 数据处理对象
///
/// 该模块采集到的 http resource 数据要传给 RUM 模块
/// - Parameter handler: RUM 模块数据接收对象
- (void)setRumResourceHandler:(id<FTRumResourceProtocol>)handler;

/// 设置 URL 过滤
/// - Parameter intakeUrlHandler: 判断是否采集回调，返回 YES 采集， NO 过滤掉
- (void)setIntakeUrlHandler:(FTIntakeUrl)intakeUrlHandler;

- (void)enableSessionDelegate:(id <NSURLSessionDelegate>)delegate;

/// 注销
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
