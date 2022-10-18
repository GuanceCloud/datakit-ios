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

NS_ASSUME_NONNULL_BEGIN
@class FTRumConfig,FTTraceConfig;
@interface URLSessionAutoInstrumentation : NSObject
@property (nonatomic,copy) NSString *sdkUrlStr;
//session 拦截处理对象 处理 resource 的链路追踪（trace）rum resource数据采集
@property (nonatomic, weak) id<URLSessionInterceptorType> interceptor;
//外部传入 rum resource 数据处理对象
@property (nonatomic, weak) id<FTRumResourceProtocol> rumResourceHandler;

+ (instancetype)sharedInstance;

- (void)setRUMConfig:(FTRumConfig *)config;

- (void)setTraceConfig:(FTTraceConfig *)config tracer:(id<FTTracerProtocol>)tracer;
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
