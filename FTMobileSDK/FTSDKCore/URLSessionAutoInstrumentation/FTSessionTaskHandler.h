//
//  FTTraceHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class FTResourceContentModel,FTResourceMetricsModel;
/// 处理单条请求，将单条请求的拦截到的数据绑定处理成 rum 需要的数据
@interface FTSessionTaskHandler : NSObject
/// 唯一标识，用于 rum  处理 resource 数据的标识
@property (nonatomic, copy, readwrite) NSString *identifier;

/// 在此拦截期间发送的初始请求。它是由`URLSession`发送的请求，而不是用户给出的请求。
@property (nonatomic, strong) NSURLRequest *request;
/// 在此拦截期间发送的请求响应。
@property (nonatomic, strong) NSURLResponse *response;
/// 在此拦截期间发生的本地错误。如果任务顺利完成，则返回`nil`。
@property (nonatomic, strong) NSError *error;
/// 拦截期间收到的任务数据。如果任务完成时出现错误，则返回`nil`。
@property (nonatomic, strong) NSMutableData *data;
/// rum resource 需要的各阶段请求时长（非必须）
@property (nonatomic, strong) FTResourceMetricsModel *metricsModel;
/// rum resource 需要的基本数据
@property (nonatomic, strong) FTResourceContentModel *contentModel;
/// trace: span_id 当没有开启 trace 功能或者没关联 rum 则返回`nil`。
@property (nonatomic, copy) NSString *spanID;
/// trace: trace_id 当没有开启 trace 功能或者没关联 rum 则返回`nil`。
@property (nonatomic, copy) NSString *traceID;

/// 初始化方法
/// - Parameter identifier: 唯一标识，根据标识
-(instancetype)initWithIdentifier:(NSString *)identifier;
///  请求响应数据
/// - Parameter data: 请求获取的数据
///
/// traceHandle 内部将在接收到 -taskCompleted 方法后将data数据绑定到 contentModel 中
- (void)taskReceivedData:(NSData *)data;

/// 请求各阶段的数据信息
/// - Parameter metrics: 数据信息
///
/// traceHandle 内部将数据处理成 rum 可接收的 metricsModel
- (void)taskReceivedMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macos(10.12));

/// 请求结束
/// - Parameters:
///   - task: 请求任务
///   - error: error 信息
///
///  整理 data 数据与 task 的一些数据 整合成 contentModel
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error;

@end
NS_ASSUME_NONNULL_END
