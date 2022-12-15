//
//  FTRumResourceProtocol.h
//  FTMobileSDK
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


#ifndef FTRumResourceProtocol_h
#define FTRumResourceProtocol_h
NS_ASSUME_NONNULL_BEGIN

@class FTResourceMetricsModel,FTResourceContentModel;
@protocol FTRumResourceProtocol <NSObject>
/// HTTP 请求开始
///
/// - Parameters:
///   - key: 请求标识
- (void)startResourceWithKey:(NSString *)key;
/// HTTP 请求开始
/// - Parameters:
///   - key: 请求标识
///   - property: 事件自定义属性(可选)
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

/// HTTP 请求数据
///
/// - Parameters:
///   - key: 请求标识
///   - metrics: 请求相关性能属性
///   - content: 请求相关数据
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;
/// HTTP 请求结束
///
/// - Parameters:
///   - key: 请求标识
- (void)stopResourceWithKey:(NSString *)key;
/// HTTP 请求结束
/// - Parameters:
///   - key: 请求标识
///   - property: 事件自定义属性(可选)
- (void)stopResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;
@optional
/// HTTP 请求数据 包含 tracer 信息 spanID、traceID
/// - Parameters:
///   - key: 请求标识
///   - metrics: 请求相关性能属性
///   - content: 请求相关数据
///   - spanID: tracer spanid
///   - traceID: tracer traceid
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(nullable NSString *)spanID traceID:(nullable NSString *)traceID;
@end
NS_ASSUME_NONNULL_END

#endif /* FTRumResourceHandler_h */
