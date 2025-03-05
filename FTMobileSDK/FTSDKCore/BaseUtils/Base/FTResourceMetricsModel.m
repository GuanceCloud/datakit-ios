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
#import "FTLog+Private.h"
#import "FTConstants.h"
@implementation FTResourceMetricsModel

-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)){
    self = [super init];
    if (self) {
        @try {
            NSMutableArray<NSURLSessionTaskTransactionMetrics *> *transactionMetrics = [NSMutableArray arrayWithArray:metrics.transactionMetrics];
            [transactionMetrics enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSURLSessionTaskTransactionMetrics * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeLocalCache||obj.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeUnknown) {
                    _resourceFetchTypeLocalCache = YES;
                    [transactionMetrics removeObjectAtIndex:idx];
                }
            }];
            _duration = [metrics.taskInterval.startDate ft_nanosecondTimeIntervalToDate:metrics.taskInterval.endDate];
            NSURLSessionTaskTransactionMetrics *taskMetrics = [transactionMetrics lastObject];
            NSDate *taskStartDate = metrics.taskInterval.startDate;
            [transactionMetrics removeLastObject];
            if(transactionMetrics.count>0){
                NSMutableArray<NSDate *> *redirectionStarts = [NSMutableArray array];
                NSMutableArray<NSDate *> *redirectionEnds = [NSMutableArray array];
                for (NSURLSessionTaskTransactionMetrics *transaction in transactionMetrics) {
                    if (transaction.fetchStartDate) {
                        [redirectionStarts addObject:transaction.fetchStartDate];
                    }
                    if (transaction.responseEndDate) {
                        [redirectionEnds addObject:transaction.responseEndDate];
                    }
                }
                if(redirectionStarts.firstObject && redirectionEnds.lastObject){
                    _resource_redirect_time = @{
                        FT_DURATION:[redirectionStarts.firstObject ft_nanosecondTimeIntervalToDate:redirectionEnds.lastObject],
                        FT_KEY_START:[taskStartDate ft_nanosecondTimeIntervalToDate:redirectionStarts.firstObject]
                    };
                }
            }
            if(taskMetrics){
                _resourceFetchTypeLocalCache = NO;
                // DNS
                if(taskMetrics.domainLookupStartDate && taskMetrics.domainLookupEndDate){
                    _resource_dns = [taskMetrics.domainLookupStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.domainLookupEndDate];
                    _resource_dns_time = @{FT_DURATION:_resource_dns,
                                           FT_KEY_START:[taskStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.domainLookupStartDate],
                    };
                }
                // TCP
                if(taskMetrics.connectStartDate && taskMetrics.connectEndDate){
                    _resource_tcp = [taskMetrics.connectStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.connectEndDate];
                    _resource_connect_time = @{FT_DURATION:_resource_tcp,
                                               FT_KEY_START:[taskStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.connectStartDate]
                    };
                }
                // SSL
                if (taskMetrics.secureConnectionStartDate &&taskMetrics.secureConnectionEndDate) {
                    _resource_ssl = [taskMetrics.secureConnectionStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.secureConnectionEndDate];
                    _resource_ssl_time = @{FT_DURATION:_resource_ssl,
                                           FT_KEY_START:[taskStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.secureConnectionStartDate]
                    };
                }
                // TTFB\first_byte
                if(taskMetrics.requestStartDate && taskMetrics.responseStartDate){
                    NSNumber *duration = [taskMetrics.requestStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseStartDate];
                    _resource_ttfb = duration;
                    _resource_first_byte = duration;
                    _resource_first_byte_time = @{
                        FT_DURATION:_resource_first_byte,
                        FT_KEY_START:[taskStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.requestStartDate],
                    };
                }
                // TRANS
                if(taskMetrics.requestStartDate && taskMetrics.responseEndDate){
                    _resource_trans =[taskMetrics.requestStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseEndDate];
                }
                // download_time
                if(taskMetrics.responseStartDate && taskMetrics.responseEndDate){
                    _resource_download_time = @{FT_DURATION:[taskMetrics.responseStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseEndDate],
                                                FT_KEY_START:[taskStartDate ft_nanosecondTimeIntervalToDate:taskMetrics.responseStartDate]
                                                
                    };
                }
                if (@available(iOS 13,macOS 10.15,tvOS 13.0, *)) {
                    _responseSize = @(taskMetrics.countOfResponseBodyBytesAfterDecoding);
                    _remoteAddress = taskMetrics.remoteAddress;
                }
            }
        } @catch (NSException *exception) {
            FTInnerLogError(@"exception: %@",exception);
        }
    }
    return self;
}
@end
