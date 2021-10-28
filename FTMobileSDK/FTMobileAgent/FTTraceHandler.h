//
//  FTTraceHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTResourceContentModel;
NS_ASSUME_NONNULL_BEGIN
@interface FTTraceHandler : NSObject
@property (nonatomic, copy, readwrite) NSString *identifier;

-(instancetype)initWithUrl:(NSURL *)url;
-(instancetype)initWithUrl:(NSURL *)url identifier:(NSString *)identifier;
/**
 * 获取 trace 添加的请求头参数
 */
- (NSDictionary *)getTraceHeader;
/**
 * 记录 trace 数据
 */
-(void)tracingContent:(NSString *)content HTTPMethod:(NSString *)HTTPMethod isError:(BOOL)isError;

-(void)rumResourceStart;

-(void)uploadResourceWithContentModel:(FTResourceContentModel *)model isError:(BOOL)isError;

- (void)resourceCompleted;

@end



@interface FTTraceHandler (Private)
@property (nonatomic, strong,nullable) NSError *error;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics;
@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSDictionary *requestHeader;
/**
 * 从 FTURLProtocol 记录resourceCompleted
 */
-(void)dealResourceDatas;
/**
 * WKWebview trace 调用方法
 */
- (void)traceRequest:(NSURLRequest *)request response:(NSURLResponse *)response startDate:(NSDate *)start taskDuration:(NSNumber *)duration error:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
