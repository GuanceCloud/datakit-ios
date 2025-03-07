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

/// 网络请求任务创建时间
@property (nonatomic, assign) long long fetchStartNsTimeInterval;
/// 网络请求任务完成时间。
@property (nonatomic, assign) long long fetchEndNsTimeInterval;
/// dns 解析开始时间
@property (nonatomic, assign) long long dnsStartNsTimeInterval;
/// dns 解析结束时间
@property (nonatomic, assign) long long dnsEndNsTimeInterval;
/// 开始建立到服务器连接的起始点
@property (nonatomic, assign) long long connectStartNsTimeInterval;
/// 资源的安全连接开始时间
@property (nonatomic, assign) long long sslStartNsTimeInterval;
/// 资源的安全连接结束时间
@property (nonatomic, assign) long long sslEndNsTimeInterval;
/// 建立连接的终点
@property (nonatomic, assign) long long connectEndNsTimeInterval;
/// 建立好连接通道后，请求开始的时间点
@property (nonatomic, assign) long long requestStartNsTimeInterval;
/// 建立好连接通道后，请求结束的时间点
@property (nonatomic, assign) long long requestEndNsTimeInterval;
/// 开始得到响应的时间点
@property (nonatomic, assign) long long responseStartNsTimeInterval;
/// 接收完最后一字节的数据的响应结束时间点
@property (nonatomic, assign) long long responseEndNsTimeInterval;
/// 重定向开始时间
@property (nonatomic, assign) long long redirectionStartNsTimeInterval;
/// 重定向结束时间
@property (nonatomic, assign) long long redirectionEndNsTimeInterval;
/// 响应结果大小 response data size
@property (nonatomic, strong, nullable) NSNumber *responseSize;
/// 远程地址
@property (nonatomic, copy, nullable) NSString *remoteAddress;
/// 初始化方法
///
/// - Parameters:
///   - metrics: SessionTaskMetric
/// - Returns: metrics 实例.
-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0),macos(10.12));

#pragma mark ========== 1.6.0 Deprecated ==========
/// 资源加载DNS解析时间 domainLookupEnd - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_dns DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 dnsStartNsTimeInterval 与 dnsEndNsTimeInterval 替换");
/// 资源加载TCP连接时间 connectEnd - connectStart
@property (nonatomic, strong) NSNumber *resource_tcp DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 connectStartNsTimeInterval 与 connectEndNsTimeInterval 替换");
/// 资源加载SSL连接时间 connectEnd - secureConnectStart
@property (nonatomic, strong) NSNumber *resource_ssl DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 secureConnectionStartNsTimeInterval 与 secureConnectionEndNsTimeInterval 替换");
/// 资源加载请求响应时间 responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_ttfb DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 responseStartNsTimeInterval 与 requestStartNsTimeInterval 替换");
/// 资源加载内容传输时间 responseEnd - responseStart
@property (nonatomic, strong) NSNumber *resource_trans DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 requestStartNsTimeInterval 与 requestEndNsTimeInterval 替换");
/// 资源加载首包时间 responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_first_byte DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 requestStartNsTimeInterval 与 requestStartNsTimeInterval 替换");
/// 资源加载时间 duration(taskInterval.endDate-taskInterval.startDate)
@property (nonatomic, strong) NSNumber *duration DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 fetchStartNsTimeInterval 与 fetchEndNsTimeInterval 替换");
@end

NS_ASSUME_NONNULL_END
