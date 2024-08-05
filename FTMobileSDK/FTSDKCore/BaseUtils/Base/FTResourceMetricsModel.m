//
//  FTResourceMetricsModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/19.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTResourceMetricsModel.h"
#import "FTResourceMetricsModel+Private.h"
#import "NSDate+FTUtil.h"
@implementation FTResourceMetricsModel

-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    self = [super init];
    if (self) {
        NSMutableArray<NSURLSessionTaskTransactionMetrics *> *transactionMetrics = [NSMutableArray arrayWithArray:metrics.transactionMetrics];
        [metrics.transactionMetrics enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSURLSessionTaskTransactionMetrics * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeLocalCache) {
                _resourceFetchTypeLocalCache = YES;
                [transactionMetrics removeObjectAtIndex:idx];
            }
        }];
        _duration = [metrics.taskInterval.startDate ft_nanosecondTimeIntervalToDate:metrics.taskInterval.endDate];
        if(transactionMetrics.count>0){
            _resourceFetchTypeLocalCache = NO;
            NSURLSessionTaskTransactionMetrics *taskMetrics = [transactionMetrics lastObject];
            _resource_dns = [taskMetrics.domainLookupStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.domainLookupEndDate];
            _resource_tcp = [taskMetrics.connectStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.connectEndDate];
            _resource_ssl = [taskMetrics.secureConnectionStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.connectEndDate];
            _resource_ttfb = [taskMetrics.requestStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseStartDate];
            _resource_trans =[taskMetrics.requestStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseEndDate];
            if(taskMetrics.domainLookupStartDate){
                _resource_first_byte = [taskMetrics.domainLookupStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseStartDate];
            }else{
                _resource_first_byte = [taskMetrics.fetchStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseStartDate];
            }
            if (@available(iOS 13,macOS 10.15, *)) {
                _responseSize = @(taskMetrics.countOfResponseBodyBytesAfterDecoding);
                _remoteAddress = taskMetrics.remoteAddress;
            }
        }
    }
    return self;
}
@end
