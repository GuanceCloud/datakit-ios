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
