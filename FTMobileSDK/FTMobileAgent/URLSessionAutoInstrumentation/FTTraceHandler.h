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
@interface FTTraceHandler : NSObject
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, strong) FTResourceMetricsModel *metricsModel;
@property (nonatomic, strong) FTResourceContentModel *contentModel;

-(instancetype)initWithUrl:(NSURL *)url identifier:(NSString *)identifier;

- (void)taskReceivedData:(NSData *)data;

- (void)taskReceivedMetrics:(NSURLSessionTaskMetrics *)metrics;

- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error;

@end
NS_ASSUME_NONNULL_END
