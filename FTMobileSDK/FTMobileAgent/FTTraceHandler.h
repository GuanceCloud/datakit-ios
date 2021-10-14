//
//  FTTraceHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface FTTraceHandler : NSObject
@property (nonatomic, strong,nullable) NSError *error;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics;

@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, assign, readonly) BOOL isSampling;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong) NSDictionary *requestHeader;

-(instancetype)initWithUrl:(NSURL *)url;

- (NSDictionary *)getTraceHeader;
-(void)tracingContent:(NSString *)content tags:(NSDictionary *)tags fileds:(NSDictionary *)fileds;
/**
 * tags :
 * resource_url
 * resource_url_host
 * resource_url_path
 * resource_url_query
 * resource_url_path_group
 * resource_type
 * resource_method
 * resource_status
 * resource_status_group
 *
 * fields :
 * duration
 * resource_size
 * resource_dns
 * resource_tcp
 * resource_ssl
 * resource_ttfb
 * resource_trans
 * resource_first_byte
 */
-(void)rumResourceCompletedWithTags:(NSDictionary *)tags fields:(NSDictionary *)fields;

-(void)resourceStart;
-(void)resourceCompleted;
/**
 * WKWebview trace 调用方法
 */
- (void)traceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error;
@end

NS_ASSUME_NONNULL_END
