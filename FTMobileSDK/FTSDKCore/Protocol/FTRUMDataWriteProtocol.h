//
//  FTRUMDataWriteProtocol.h
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


#ifndef FTRUMDataWriteProtocol_h
#define FTRUMDataWriteProtocol_h
NS_ASSUME_NONNULL_BEGIN
/// RUM 数据写入接口
@protocol FTRUMDataWriteProtocol <NSObject>

/// rum 数据写入
/// - Parameters:
///   - source: 数据来源 view|action|resource|error
///   - tags: 属性
///   - fields: 指标
///   - tm: 数据产生时间戳(ns)
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time;

@optional
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time updateTime:(long long)updateTime;

- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time updateTime:(long long)updateTime cache:(BOOL)cache;
/// extension widget 采集的 RUM 数据写入
/// - Parameters:
///   - source: 数据来源 view|action|resource|error
///   - tags: 属性
///   - fields: 指标
///   - time: 数据产生时间戳(ns)
- (void)extensionRumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields time:(long long)time;

/// 针对 session on error 数据切换成 cache writer，数据写入类型为 RUMCache
- (void)isCacheWriter:(BOOL)cache;

/// 上次 APP 是否有崩溃 ANR 等数据写在本地,errorDate 崩溃时间
- (void)lastFatalErrorIfFound:(long long)errorDate;

/// 处理 rum cache 数据，看是否需要删除
- (void)checkRUMSessionOnErrorDatasWithExpireTime:(long long)expireTime;
@end
NS_ASSUME_NONNULL_END
#endif /* FTRUMDataWriteProtocol_h */
