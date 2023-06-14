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
///   - tags:  属性
///   - fields:  指标
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields;

/// rum 数据写入
/// - Parameters:
///   - source: 数据来源 view|action|resource|error
///   - tags: 属性
///   - fields: 指标
///   - tm: 数据产生时间戳(ns)
- (void)rumWrite:(NSString *)source tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
@end
NS_ASSUME_NONNULL_END
#endif /* FTRUMDataWriteProtocol_h */
