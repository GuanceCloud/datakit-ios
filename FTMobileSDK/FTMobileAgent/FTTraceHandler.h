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
/**
 * 获取 trace 添加的请求头参数
 */
- (NSDictionary *)getTraceHeader;
/**
 * 记录 trace 数据
 */
-(void)tracingContent:(NSString *)content tags:(NSDictionary *)tags fileds:(NSDictionary *)fileds;

/**
 * RUM ResourceStart
 */
-(void)rumResourceStart;
/**
 * RUM Resource Completed
 */
-(void)rumResourceCompletedWithTags:(NSDictionary *)tags fields:(NSDictionary *)fields;
/**
 * RUM Resource Completed Error
 */
-(void)rumResourceCompletedErrorWithTags:(NSDictionary *)tags fields:(NSDictionary *)fields;

    
/**
 * 从 FTURLProtocol 记录resourceCompleted
 */
-(void)resourceCompleted;
/**
 * WKWebview trace 调用方法
 */
- (void)traceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error;
@end

NS_ASSUME_NONNULL_END
