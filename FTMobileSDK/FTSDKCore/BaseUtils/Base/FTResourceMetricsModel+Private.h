//
//  FTResourceMetricsModel+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/8/2.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTResourceMetricsModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTResourceMetricsModel ()
@property (nonatomic, assign) BOOL resourceFetchTypeLocalCache;
/// 同 DNS 解析时间 格式为 {duration: number(ns), start: number(ns)}
/// duration:与resource_dns指标相同；
/// start: 表示资源从开始请求到资源开始解析的时间段，m单位为 ns。 即 domainLookupStart - startTime
@property (nonatomic, strong) NSDictionary *resource_dns_time;
/// 资源重定向耗时， 格式与计算方式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_redirect_time;
/// 资源下载耗时，格式与计算方式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_download_time;
/// 同资源加载首包时间，格式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_first_byte_time;
/// 同资源加载 SSL 连接时间，格式与计算方式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_ssl_time;
/// 资源连接耗时
@property (nonatomic, strong) NSDictionary *resource_connect_time;

- (NSNumber *)dns;
- (NSNumber *)tcp;
- (NSNumber *)ssl;
- (NSNumber *)ttfb;
- (NSNumber *)trans;
- (NSNumber *)firstByte;
- (NSNumber *)fetchInterval;
@end

NS_ASSUME_NONNULL_END
