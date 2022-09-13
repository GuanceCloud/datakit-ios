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
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *span_id;
@property (nonatomic, copy, readwrite) NSString *trace_id;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSNumber *duration;
-(instancetype)initWithUrl:(NSURL *)url identifier:(NSString *)identifier;
/**
 * 获取 trace 添加的请求头参数
 */
- (NSDictionary *)getTraceHeader;

@end
NS_ASSUME_NONNULL_END
