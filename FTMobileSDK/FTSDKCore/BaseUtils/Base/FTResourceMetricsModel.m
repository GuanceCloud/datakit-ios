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
        NSURLSessionTaskTransactionMetrics *taskMes = [transactionMetrics lastObject];
        _resource_dns = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.domainLookupEndDate];
        _resource_tcp = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.connectStartDate toDate:taskMes.connectEndDate];
        _resource_ssl = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.secureConnectionStartDate toDate:taskMes.connectEndDate];
        _resource_ttfb = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseStartDate];
        _resource_trans =[FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseEndDate];
        _duration = [FTDateUtil nanosecondTimeIntervalSinceDate:metrics.taskInterval.startDate toDate:metrics.taskInterval.endDate];
        if(taskMes.domainLookupStartDate){
            _resource_first_byte = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.responseStartDate];
        }else{
            _resource_first_byte = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.fetchStartDate toDate:taskMes.responseStartDate];
        }
        if (@available(iOS 13,macOS 10.15, *)) {
            _responseSize = @(taskMes.countOfResponseBodyBytesAfterDecoding);
        }
    }
    return self;
}
@end
