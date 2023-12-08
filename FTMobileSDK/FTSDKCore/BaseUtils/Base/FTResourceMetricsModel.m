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
        self.resource_dns = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.domainLookupStartDate toDate:taskMetrics.domainLookupEndDate];
        self.resource_tcp = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.connectStartDate toDate:taskMetrics.connectEndDate];
        self.resource_ssl = taskMetrics.secureConnectionStartDate!=nil ? [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.secureConnectionStartDate toDate:taskMetrics.connectEndDate]:@0;
        self.resource_ttfb = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.requestStartDate toDate:taskMetrics.responseStartDate];
        self.resource_trans =[FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.requestStartDate toDate:taskMetrics.responseEndDate];
        self.duration = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.fetchStartDate toDate:taskMetrics.requestEndDate];
        self.resource_first_byte = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMetrics.domainLookupStartDate toDate:taskMetrics.responseStartDate];
        if (@available(iOS 13,macOS 10.15, *)) {
            self.responseSize = @( taskMetrics.countOfResponseBodyBytesAfterDecoding);
        }
    }
    return self;
}
@end
