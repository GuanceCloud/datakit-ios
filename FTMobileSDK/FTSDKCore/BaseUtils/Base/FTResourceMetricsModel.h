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
///资源加载DNS解析时间 domainLookupEnd - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_dns;
///资源加载TCP连接时间 connectEnd - connectStart
@property (nonatomic, strong) NSNumber *resource_tcp;
///资源加载SSL连接时间 connectEnd - secureConnectStart
@property (nonatomic, strong) NSNumber *resource_ssl;
///资源加载请求响应时间 responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_ttfb;
///资源加载内容传输时间 responseEnd - responseStart
@property (nonatomic, strong) NSNumber *resource_trans;
///资源加载首包时间 responseStart - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_first_byte;
///资源加载时间 duration(responseEnd-fetchStartDate)
@property (nonatomic, strong) NSNumber *duration;
///响应结果大小 response data size
@property (nonatomic, strong) NSNumber *responseSize;
/// 初始化方法
///
/// - Parameters:
///   - metrics: SessionTaskMetric
/// - Returns: metrics 实例.
-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0),macosx(10.12));

@end

NS_ASSUME_NONNULL_END
