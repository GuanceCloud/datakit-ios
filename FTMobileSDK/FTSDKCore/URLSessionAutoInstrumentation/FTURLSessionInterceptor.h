//
//  FTURLSessionInterceptor.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTURLSessionDelegate.h"
NS_ASSUME_NONNULL_BEGIN

/// URL Session 的拦截器，实现 RUM Resource 数据的采集，Trace 链路追踪
@interface FTURLSessionInterceptor : NSObject

/// 单例
+ (instancetype)shared;

/// 告诉拦截器修改 URL 请求，开启自动链路追踪时，调用此方法会在请求头添加链路信息，
/// 若未开启，则直接返回传入 request
/// - Parameter request: 初始请求
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request;

/// 告诉拦截器创建了一个任务
/// - Parameter task: 任务
- (void)interceptTask:(NSURLSessionTask *)task;

/// 告诉拦截器任务已经收到了一些预期的数据。
/// - Parameters:
///   - task: 提供数据的数据任务。
///   - data: 数据对象
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data;

/// 告诉拦截器已经为给定任务收集了指标。
/// - Parameters:
///   - task: 收集了指标的任务
///   - metrics: 收集的指标。
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics;
/// 告诉拦截器任务已经完成
/// - Parameters:
///   - task: 完成数据传输的任务。
///   - error:  如果发生错误，则返回一个错误对象，表示传输如何失败，否则返回`nil`。
///   - extraProvider: 额外添加的自定义 RUM 资源属性
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider;
@end

NS_ASSUME_NONNULL_END
