//
//  FTResourceMetricsModel.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/11/19.
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
            _fetchStartNsTimeInterval = [metrics.taskInterval.startDate ft_nanosecondTimeStamp];
            _fetchEndNsTimeInterval = [metrics.taskInterval.endDate ft_nanosecondTimeStamp];
            NSURLSessionTaskTransactionMetrics *taskMetrics = [transactionMetrics lastObject];
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
                    _redirectionStartNsTimeInterval = [redirectionStarts.firstObject ft_nanosecondTimeStamp];
                    _redirectionEndNsTimeInterval = [redirectionEnds.lastObject ft_nanosecondTimeStamp];
                }
            }
            if(taskMetrics!=nil){
                _resourceFetchTypeLocalCache = NO;
                // DNS
                _dnsStartNsTimeInterval = taskMetrics.domainLookupStartDate?[taskMetrics.domainLookupStartDate ft_nanosecondTimeStamp]:0;
                _dnsEndNsTimeInterval = taskMetrics.domainLookupEndDate?[taskMetrics.domainLookupEndDate ft_nanosecondTimeStamp]:0;
                _connectStartNsTimeInterval = taskMetrics.connectStartDate?[taskMetrics.connectStartDate ft_nanosecondTimeStamp]:0;
                _connectEndNsTimeInterval = taskMetrics.connectEndDate?[taskMetrics.connectEndDate ft_nanosecondTimeStamp]:0;
                _sslStartNsTimeInterval = taskMetrics.secureConnectionStartDate?[taskMetrics.secureConnectionStartDate ft_nanosecondTimeStamp]:0;
                _sslEndNsTimeInterval = taskMetrics.secureConnectionEndDate?[taskMetrics.secureConnectionEndDate ft_nanosecondTimeStamp]:0;
                _requestStartNsTimeInterval = taskMetrics.requestStartDate?[taskMetrics.requestStartDate ft_nanosecondTimeStamp]:0;
                _requestEndNsTimeInterval = taskMetrics.requestEndDate?[taskMetrics.requestEndDate ft_nanosecondTimeStamp]:0;
                _responseStartNsTimeInterval = taskMetrics.responseStartDate?[taskMetrics.responseStartDate ft_nanosecondTimeStamp]:0;
                _responseEndNsTimeInterval = taskMetrics.responseEndDate?[taskMetrics.responseEndDate ft_nanosecondTimeStamp]:0;
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (NSNumber *)dns{
    if (self.dnsEndNsTimeInterval>0 && self.dnsStartNsTimeInterval>0) {
        long long duration = self.dnsEndNsTimeInterval - self.dnsStartNsTimeInterval;
        if(duration >= 0 && duration < [self.fetchInterval longLongValue]){
            return @(duration);
        }
    }
    return self.resource_dns;
}
- (NSNumber *)tcp{
    if (self.connectEndNsTimeInterval>0 && self.connectStartNsTimeInterval>0) {
        long long duration = self.connectEndNsTimeInterval - self.connectStartNsTimeInterval;
        if(duration >= 0){
            return @(duration);
        }
    }
    return self.resource_tcp;
}
- (NSNumber *)ssl{
    if (self.sslEndNsTimeInterval>0 && self.sslStartNsTimeInterval>0) {
        long long duration = self.sslEndNsTimeInterval - self.sslStartNsTimeInterval;
        if(duration >= 0){
            return @(duration);
        }
    }
    return self.resource_ssl;
}
// ttfb == firstByte
- (NSNumber *)ttfb{
    if (self.responseStartNsTimeInterval>0 && self.requestStartNsTimeInterval>0) {
        long long duration = self.responseStartNsTimeInterval - self.requestStartNsTimeInterval;
        if(duration >= 0){
            return @(duration);
        }
    }
    return self.resource_ttfb;
}
- (NSNumber *)trans{
    if (self.responseEndNsTimeInterval>0 && self.responseStartNsTimeInterval>0) {
        long long duration = self.responseEndNsTimeInterval - self.responseStartNsTimeInterval;
        if(duration >= 0){
            return @(duration);
        }
    }
    return self.resource_trans;
}
- (NSNumber *)firstByte{
    if (self.responseStartNsTimeInterval>0 && self.requestStartNsTimeInterval>0) {
        long long duration = self.responseStartNsTimeInterval - self.requestStartNsTimeInterval;
        if(duration>0){
            return @(duration);
        }
    }
    return self.resource_first_byte;
}
- (NSNumber *)fetchInterval{
    if (self.fetchEndNsTimeInterval>0 && self.fetchStartNsTimeInterval>0) {
        long long duration = self.fetchEndNsTimeInterval - self.fetchStartNsTimeInterval;
        if(duration >= 0){
            return @(duration);
        }
    }
    return self.duration;
}
#pragma clang diagnostic pop
-(NSDictionary *)resource_redirect_time{
    if (self.redirectionEndNsTimeInterval>0 && self.redirectionStartNsTimeInterval>0) {
        long long duration = _redirectionEndNsTimeInterval-_redirectionStartNsTimeInterval;
        if(duration >= 0){
            return  @{
                FT_DURATION:@(duration),
                FT_KEY_START:@(_redirectionStartNsTimeInterval-_fetchStartNsTimeInterval)
            };
        }
    }
    return nil;
}
-(NSDictionary *)resource_dns_time{
    NSNumber *duration = self.dns;
    if(duration != nil){
        return  @{
            FT_DURATION:duration,
            FT_KEY_START:@(_dnsStartNsTimeInterval-_fetchStartNsTimeInterval)
        };
    }
    return nil;
}
-(NSDictionary *)resource_ssl_time{
    NSNumber *duration = self.ssl;
    if(duration != nil){
        return  @{
            FT_DURATION:duration,
            FT_KEY_START:@(_sslStartNsTimeInterval-_fetchStartNsTimeInterval)
        };
    }
    return nil;
}
-(NSDictionary *)resource_connect_time{
    NSNumber *duration = self.tcp;
    if(duration != nil){
        return  @{
            FT_DURATION:duration,
            FT_KEY_START:@(_connectStartNsTimeInterval-_fetchStartNsTimeInterval)
        };
    }
    return nil;
}
-(NSDictionary *)resource_first_byte_time{
    NSNumber *duration = self.firstByte;
    if(duration != nil){
        return  @{
            FT_DURATION:duration,
            FT_KEY_START:@(_requestStartNsTimeInterval-_fetchStartNsTimeInterval)
        };
    }
    return nil;
}
-(NSDictionary *)resource_download_time{
    NSNumber *duration = self.trans;
    if(duration != nil){
        return  @{
            FT_DURATION:duration,
            FT_KEY_START:@(_responseStartNsTimeInterval-_fetchStartNsTimeInterval)
        };
    }
    return nil;
}
@end
