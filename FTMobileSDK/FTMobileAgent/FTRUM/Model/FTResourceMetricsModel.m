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
      NSURLSessionTaskTransactionMetrics *taskMes = [metrics.transactionMetrics lastObject];
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

//-(void)setDnsStart:(long)start end:(long)end{
//    if (end > start) {
//        self.resource_dns = @(end-start);
//    }
//}
//-(void)setTcpStart:(long)start end:(long)end{
//    if (end > start) {
//        self.resource_tcp = @(end-start);
//    }
//}
//-(void)setSslStart:(long)start end:(long)end{
//    if (end > start) {
//        self.resource_ssl = @(end-start);
//    }
//}
//-(void)setTtfbStart:(long)start end:(long)end{
//    if (end > start) {
//        self.resource_ttfb = @(end-start);
//    }
//}
//-(void)setTransStart:(long)start end:(long)end{
//    if (end > start) {
//        self.resource_trans = @(end-start);
//    }
//}
//-(void)setFirstByteStart:(long)start end:(long)end{
//    if (end > start) {
//        self.resource_first_byte = @(end-start);
//    }
//}
//-(void)setDurationStart:(long)start end:(long)end{
//    if (end > start) {
//        self.duration = @(end-start);
//    }
//}
@end
