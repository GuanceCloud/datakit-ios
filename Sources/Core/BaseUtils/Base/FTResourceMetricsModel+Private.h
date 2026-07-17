//
//  FTResourceMetricsModel+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/8/2.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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
//

#import "FTResourceMetricsModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTResourceMetricsModel ()
@property (nonatomic, assign) BOOL resourceFetchTypeLocalCache;
/// Same as DNS resolution time, format is {duration: number(ns), start: number(ns)}
/// duration: same as resource_dns metric;
/// start: represents the time period from the start of the request to the start of resource resolution, unit is ns. That is domainLookupStart - startTime
@property (nonatomic, strong, nullable) NSDictionary *resource_dns_time;
/// Resource redirect time consumption, format and calculation method same as resource_dns_time
@property (nonatomic, strong, nullable) NSDictionary *resource_redirect_time;
/// Resource download time consumption, format and calculation method same as resource_dns_time
@property (nonatomic, strong, nullable) NSDictionary *resource_download_time;
/// Same as resource loading first packet time, format same as resource_dns_time
@property (nonatomic, strong, nullable) NSDictionary *resource_first_byte_time;
/// Same as resource loading SSL connection time, format and calculation method same as resource_dns_time
@property (nonatomic, strong, nullable) NSDictionary *resource_ssl_time;
/// Resource connection time consumption
@property (nonatomic, strong, nullable) NSDictionary *resource_connect_time;

- (NSNumber *)dns;
- (NSNumber *)tcp;
- (NSNumber *)ssl;
- (NSNumber *)ttfb;
- (NSNumber *)trans;
- (NSNumber *)firstByte;
- (NSNumber *)fetchInterval;
@end

NS_ASSUME_NONNULL_END
