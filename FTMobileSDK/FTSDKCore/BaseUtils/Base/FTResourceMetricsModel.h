//
//  FTResourceMetricsModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/19.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 资源加载时间数据模型
@interface FTResourceMetricsModel : NSObject
/// 资源加载DNS解析时间 domainLookupEnd - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_dns;
/// 同 DNS 解析时间 格式为 {duration: number(ns), start: number(ns)}
/// duration:与resource_dns指标相同；
/// start: 表示资源从开始请求到资源开始解析的时间段，m单位为 ns。 即 domainLookupStart - startTime
@property (nonatomic, strong) NSDictionary *resource_dns_time;
/// 资源加载TCP连接时间 connectEnd - connectStart
@property (nonatomic, strong) NSNumber *resource_tcp;
/// 资源连接耗时
@property (nonatomic, strong) NSDictionary *resource_connect_time;
/// 资源加载SSL连接时间 connectEnd - secureConnectStart
@property (nonatomic, strong) NSNumber *resource_ssl;
/// 同资源加载 SSL 连接时间，格式与计算方式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_ssl_time;
/// 资源加载请求响应时间 responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_ttfb;
/// 资源加载内容传输时间 responseEnd - responseStart
@property (nonatomic, strong) NSNumber *resource_trans;
/// 资源加载首包时间 responseStart - requestStartDate
@property (nonatomic, strong) NSNumber *resource_first_byte;
/// 同资源加载首包时间，格式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_first_byte_time;
/// 资源下载耗时，格式与计算方式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_download_time;
/// 资源重定向耗时， 格式与计算方式同 resource_dns_time 一致
@property (nonatomic, strong) NSDictionary *resource_redirect_time;
/// 资源加载时间 duration(responseEnd-fetchStartDate)
@property (nonatomic, strong) NSNumber *duration;
/// 响应结果大小 response data size
@property (nonatomic, strong, nullable) NSNumber *responseSize;
/// 远程地址
@property (nonatomic, copy) NSString *remoteAddress;
/// 初始化方法
///
/// - Parameters:
///   - metrics: SessionTaskMetric
/// - Returns: metrics 实例.
-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0),macos(10.12));

@end

NS_ASSUME_NONNULL_END
