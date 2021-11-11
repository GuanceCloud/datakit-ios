//
//  FTResourceContentModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTResourceContentModel : NSObject
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDictionary *requestHeader;
@property (nonatomic, strong) NSDictionary *responseHeader;
@property (nonatomic, copy) NSString *resourceMethod;
@property (nonatomic, copy) NSString *responseBody;
@property (nonatomic, assign) NSInteger httpStatusCode;

@property (nonatomic, strong) NSError *error;
@end

@interface FTResourceMetricsModel : NSObject
//资源加载DNS解析时间 domainLookupEnd - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_dns;
//资源加载TCP连接时间 connectEnd - connectStart
@property (nonatomic, strong) NSNumber *resource_tcp;
//资源加载SSL连接时间 connectEnd - secureConnectStart
@property (nonatomic, strong) NSNumber *resource_ssl;
//资源加载请求响应时间 responseStart - requestStart
@property (nonatomic, strong) NSNumber *resource_ttfb;
//资源加载内容传输时间 responseEnd - responseStart
@property (nonatomic, strong) NSNumber *resource_trans;
//资源加载首包时间 responseStart - domainLookupStart
@property (nonatomic, strong) NSNumber *resource_first_byte;
//资源加载时间 duration(responseEnd-fetchStartDate)
@property (nonatomic, strong) NSNumber *duration;
-(instancetype)initWithTaskMetrics:(NSURLSessionTaskMetrics *)metrics;

-(void)setDnsStart:(long)start end:(long)end;
-(void)setTcpStart:(long)start end:(long)end;
-(void)setSslStart:(long)start end:(long)end;
-(void)setTtfbStart:(long)start end:(long)end;
-(void)setTransStart:(long)start end:(long)end;
-(void)setFirstByteStart:(long)start end:(long)end;
-(void)setDurationStart:(long)start end:(long)end;

@end
NS_ASSUME_NONNULL_END
