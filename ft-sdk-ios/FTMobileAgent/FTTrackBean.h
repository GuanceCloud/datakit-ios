//
//  FTTrackBean.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/3/12.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTTrackBean : NSObject
//当前数据点所属的指标集 （必填）
@property (nonatomic, copy) NSString *measurement;
//自定义标签  （可选）
@property (nonatomic, strong) NSDictionary *tags;
//自定义指标  （必填）
@property (nonatomic, strong) NSDictionary *field;
//需要为毫秒级13位时间戳 （可选） 不传则为当前时间
@property (nonatomic, assign) long long  timeMillis;
@end
@interface FTReportBean : NSObject
@property (nonatomic, copy) NSString *source;

@end
@interface FTLoggingBean : NSObject
///指定当前日志的来源，比如如果来源于 Ngnix，可指定为 Nginx，同一应用产生的日志 source 应该一样 (必填)
@property (nonatomic, copy) NSString *measurement;

///日志内容，纯文本或 JSONString 都可以 (必填)
@property (nonatomic, copy) NSString *content;
///自定义标签  （可选）
@property (nonatomic, strong) NSDictionary *tags;
///自定义指标  （可选）
@property (nonatomic, strong) NSDictionary *field;
///用于链路日志，当前链路的请求响应时间，微秒为单位
@property (nonatomic, assign) int64_t duration;
@end
NS_ASSUME_NONNULL_END
