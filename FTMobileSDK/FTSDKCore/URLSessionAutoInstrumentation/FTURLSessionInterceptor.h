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

/// URL Session interceptor, implements RUM Resource data collection, Trace link tracking
@interface FTURLSessionInterceptor : NSObject

/// Singleton
+ (instancetype)shared;

/// Tell the interceptor to modify URL request, when automatic link tracking is enabled, calling this method will add link information to the request header,
/// if not enabled, directly return the passed request
/// - Parameter request: Initial request
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request;

/// Tell the interceptor that a task has been created
/// - Parameter task: Task
- (void)interceptTask:(NSURLSessionTask *)task;

/// Tell the interceptor that the task has received some expected data.
/// - Parameters:
///   - task: The data task that provides the data.
///   - data: Data object
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data;

/// Tell the interceptor that metrics have been collected for the given task.
/// - Parameters:
///   - task: The task for which metrics were collected
///   - metrics: The collected metrics.
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics;
/// Tell the interceptor that the task has completed
/// - Parameters:
///   - task: The task that completed data transmission.
///   - error:  If an error occurred, returns an error object indicating how the transmission failed, otherwise returns `nil`.
///   - extraProvider: Additional custom RUM resource properties
- (void)taskCompleted:(NSURLSessionTask *)task error:(nullable NSError *)error extraProvider:(nullable ResourcePropertyProvider)extraProvider;
@end

NS_ASSUME_NONNULL_END
