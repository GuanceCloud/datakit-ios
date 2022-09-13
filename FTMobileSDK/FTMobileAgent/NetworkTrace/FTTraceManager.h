//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRumResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@protocol URLSessionInterceptorType<NSObject>
- (NSURLRequest *)injectTraceHeader:(NSURLRequest *)request;
- (void)taskCreated:(NSURLSessionTask *)task  session:(NSURLSession *)session;
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics;
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data;
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error;

@end
@class FTTraceHandler;
@interface FTTraceManager : NSObject<URLSessionInterceptorType>
@property (nonatomic, weak) id<FTRumResourceProtocol> rumDelegate;
+ (instancetype)sharedInstance;
/**
 * 判断是否是 SDK 内部 url
 * 内部 url 不进行采集
 * @param url   请求 URL
 */
- (BOOL)isInternalURL:(NSURL *)url;
/**
 * 获取 trace 需要添加的请求头
 * @param key   请求标识
 * @param url   请求 URL
 */
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;


- (FTTraceHandler *)getTraceHandler:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
