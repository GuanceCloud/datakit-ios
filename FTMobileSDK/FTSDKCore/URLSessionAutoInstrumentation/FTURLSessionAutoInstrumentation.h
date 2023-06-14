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
#import "FTEnumConstant.h"
NS_ASSUME_NONNULL_BEGIN
@class FTRumConfig,FTTraceConfig;
///  url session 自动化 采集 rum 数据，实现 trace 功能的对象
@interface FTURLSessionAutoInstrumentation : NSObject

/// session 拦截处理对象 处理 resource 的链路追踪（trace）rum resource数据采集
@property (nonatomic, weak ,readonly) id<FTURLSessionInterceptorDelegate> interceptor;
/// 向外部提供处理用户自定义 resource 数据的对象
@property (nonatomic, weak ,readonly) id<FTExternalResourceProtocol> externalResourceHandler;

/// 单例
+ (instancetype)sharedInstance;

/// 设置 rum 配置项，采集 resource 数据
/// - Parameter config: rum 配置项
- (void)setRUMEnableTraceUserResource:(BOOL)enable;

/// 设置 trace 配置项，开启 trace
/// - Parameters:
///   - config: trace 配置项
- (void)setTraceEnableAutoTrace:(BOOL)enableAutoTrace enableLinkRumData:(BOOL)enableLinkRumData sampleRate:(int)sampleRate traceType:(NetworkTraceType)traceType;
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
/// 注销
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
