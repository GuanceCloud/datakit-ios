//
//  FTTraceHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class FTResourceContentModel,FTResourceMetricsModel;
/// Handles a single request, binding intercepted data to the format required by RUM
@interface FTSessionTaskHandler : NSObject
/// Unique identifier, used as the identifier for RUM resource processing
@property (nonatomic, copy, readwrite) NSString *identifier;

/// The initial request sent during this interception. It is the request sent by `URLSession`, not the one provided by the user.
@property (nonatomic, strong) NSURLRequest *request;
/// The response received during this interception.
@property (nonatomic, strong) NSURLResponse *response;
/// The local error that occurred during this interception. Returns `nil` if the task completed successfully.
@property (nonatomic, strong) NSError *error;
/// The task data received during this interception. Returns `nil` if the task completed with an error.
@property (nonatomic, strong) NSData *data;
/// Request duration for each stage required by RUM resource (optional)
@property (nonatomic, strong) FTResourceMetricsModel *metricsModel;
/// Basic data required by RUM resource
@property (nonatomic, strong) FTResourceContentModel *contentModel;
/// trace: span_id. Returns `nil` if trace is not enabled or not associated with RUM.
@property (nonatomic, copy) NSString *spanID;
/// trace: trace_id. Returns `nil` if trace is not enabled or not associated with RUM.
@property (nonatomic, copy) NSString *traceID;

/// Initialization method
/// - Parameter identifier: Unique identifier, based on the identifier
-(instancetype)initWithIdentifier:(NSString *)identifier;
/// Request response data
/// - Parameter data: Data received from the request
///
/// Internally, traceHandle will bind the data to contentModel after receiving -taskCompleted
- (void)taskReceivedData:(NSData *)data;

/// Data for each stage of the request
/// - Parameter metrics: Metrics information
///
/// Internally, traceHandle will process the data into a metricsModel that RUM can accept
- (void)taskReceivedMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macos(10.12));
- (void)taskReceivedMetrics:(NSURLSessionTaskMetrics *)metrics custom:(BOOL)custom API_AVAILABLE(macos(10.12));
/// Request finished
/// - Parameters:
///   - task: Request task
///   - error: Error information
///
/// Organize data and some information from the task into contentModel
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error;

@end
NS_ASSUME_NONNULL_END
