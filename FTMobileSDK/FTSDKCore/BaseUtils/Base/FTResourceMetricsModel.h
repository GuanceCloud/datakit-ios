//
//  FTResourceMetricsModel.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/11/19.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resource loading time data model
@interface FTResourceMetricsModel : NSObject

/// Network request task creation time
@property (nonatomic, assign) long long fetchStartNsTimeInterval;
/// Network request task completion time.
@property (nonatomic, assign) long long fetchEndNsTimeInterval;
/// DNS resolution start time
@property (nonatomic, assign) long long dnsStartNsTimeInterval;
/// DNS resolution end time
@property (nonatomic, assign) long long dnsEndNsTimeInterval;
/// Start point for establishing connection to server
@property (nonatomic, assign) long long connectStartNsTimeInterval;
/// Resource secure connection start time
@property (nonatomic, assign) long long sslStartNsTimeInterval;
/// Resource secure connection end time
@property (nonatomic, assign) long long sslEndNsTimeInterval;
/// End point for establishing connection
@property (nonatomic, assign) long long connectEndNsTimeInterval;
/// Time point when request starts after connection channel is established
@property (nonatomic, assign) long long requestStartNsTimeInterval;
/// Time point when request ends after connection channel is established
@property (nonatomic, assign) long long requestEndNsTimeInterval;
/// Time point when response starts
@property (nonatomic, assign) long long responseStartNsTimeInterval;
/// Response end time point when receiving the last byte of data
@property (nonatomic, assign) long long responseEndNsTimeInterval;
/// Redirect start time
@property (nonatomic, assign) long long redirectionStartNsTimeInterval;
/// Redirect end time
@property (nonatomic, assign) long long redirectionEndNsTimeInterval;
/// Response body + header
@property (nonatomic, strong, nullable) NSNumber *responseSize;
/// Request body + header
@property (nonatomic, strong, nullable) NSNumber *requestSize;
/// Remote address
@property (nonatomic, copy, nullable) NSString *remoteAddress;
/// The network protocol used to fetch the resource
@property (nonatomic, copy, nullable) NSString *resourceHttpProtocol;
/// This property is set to YES if a persistent connection was used to fetch the resource
@property (nonatomic, assign) BOOL reusedConnection;


/// Initialization method
///
/// - Parameters:
///   - metrics: SessionTaskMetric
/// - Returns: metrics instance.
-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0),macos(10.12));

#pragma mark ========== 1.6.0 Deprecated ==========
/// Resource loading DNS resolution time domainLookupEnd - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_dns DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use dnsStartNsTimeInterval and dnsEndNsTimeInterval instead");
/// Resource loading TCP connection time connectEnd - connectStart
@property (nonatomic, strong) NSNumber *resource_tcp DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use connectStartNsTimeInterval and connectEndNsTimeInterval instead");
/// Resource loading SSL connection time connectEnd - secureConnectStart
@property (nonatomic, strong) NSNumber *resource_ssl DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use secureConnectionStartNsTimeInterval and secureConnectionEndNsTimeInterval instead");
/// Resource loading request response time responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_ttfb DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use responseStartNsTimeInterval and requestStartNsTimeInterval instead");
/// Resource loading content transmission time responseEnd - responseStart
@property (nonatomic, strong) NSNumber *resource_trans DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use requestStartNsTimeInterval and requestEndNsTimeInterval instead");
/// Resource loading first packet time responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_first_byte DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use requestStartNsTimeInterval and requestStartNsTimeInterval instead");
/// Resource loading time duration(taskInterval.endDate-taskInterval.startDate)
@property (nonatomic, strong) NSNumber *duration DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use fetchStartNsTimeInterval and fetchEndNsTimeInterval instead");
@end

NS_ASSUME_NONNULL_END
