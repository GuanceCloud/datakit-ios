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
@class FTRumConfig,FTTraceConfig;
///  url session 自动化 采集 rum 数据，实现 trace 功能的对象
@interface FTURLSessionAutoInstrumentation : NSObject

/// sdk 内部的数据上传 url
@property (nonatomic,copy) NSString *sdkUrlStr;
/// session 拦截处理对象 处理 resource 的链路追踪（trace）rum resource数据采集
@property (nonatomic, weak) id<FTURLSessionInterceptorDelegate> interceptor;
/// 处理外部传入 rum resource 数据的对象
@property (nonatomic, weak ,readonly) id<FTExternalResourceProtocol> rumResourceHandler;

/// 单例
+ (instancetype)sharedInstance;

/// 设置 rum 配置项，采集 resource 数据
/// - Parameter config: rum 配置项
- (void)setRUMConfig:(FTRumConfig *)config;

/// 设置 trace 配置项，开启 trace
/// - Parameters:
///   - config: trace 配置项
- (void)setTraceConfig:(FTTraceConfig *)config;

/// 获取实现 tracerProtocol 处理获取与解包 trace 请求头的对象
-(id<FTTracerProtocol> _Nullable)tracer;
/// 注销
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
