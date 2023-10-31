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
        self.resource_dns = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.domainLookupEndDate];
        self.resource_tcp = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.connectStartDate toDate:taskMes.connectEndDate];
        self.resource_ssl = taskMes.secureConnectionStartDate!=nil ? [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.secureConnectionStartDate toDate:taskMes.connectEndDate]:@0;
        self.resource_ttfb = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseStartDate];
        self.resource_trans =[FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.requestStartDate toDate:taskMes.responseEndDate];
        self.duration = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.fetchStartDate toDate:taskMes.requestEndDate];
        self.resource_first_byte = [FTDateUtil nanosecondTimeIntervalSinceDate:taskMes.domainLookupStartDate toDate:taskMes.responseStartDate];
    }
    return self;
}
@end
