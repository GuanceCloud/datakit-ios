//
//  FTResourceMetricsModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/19.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTResourceMetricsModel.h"
#import "FTDateUtil.h"
@implementation FTResourceMetricsModel

-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    self = [super init];
    if (self) {
        NSMutableArray<NSURLSessionTaskTransactionMetrics *> *transactionMetrics = [NSMutableArray arrayWithArray:metrics.transactionMetrics];
        [metrics.transactionMetrics enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSURLSessionTaskTransactionMetrics * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeLocalCache) {
                [transactionMetrics removeObjectAtIndex:idx];
            }
        }];
        NSURLSessionTaskTransactionMetrics *taskMetrics = [transactionMetrics lastObject];
        _resource_dns = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.domainLookupStartDate toDate:taskMetrics.domainLookupEndDate];
        _resource_tcp = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.connectStartDate toDate:taskMetrics.connectEndDate];
        _resource_ssl = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.secureConnectionStartDate toDate:taskMetrics.connectEndDate];
        _resource_ttfb = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.requestStartDate toDate:taskMetrics.responseStartDate];
        _resource_trans =[FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.requestStartDate toDate:taskMetrics.responseEndDate];
        _duration = [FTDateUtil nanosecondTimeIntervalSinceDate:metrics.taskInterval.startDate toDate:metrics.taskInterval.endDate];
        if(taskMetrics.domainLookupStartDate){
            _resource_first_byte = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.domainLookupStartDate toDate:taskMetrics.responseStartDate];
        }else{
            _resource_first_byte = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.fetchStartDate toDate:taskMetrics.responseStartDate];
        }
        if (@available(iOS 13,macOS 10.15, *)) {
            _responseSize = @(taskMetrics.countOfResponseBodyBytesAfterDecoding);
        }
    }
    return self;
}
@end
