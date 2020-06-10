//
//  FTTrackBean.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/3/12.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
///事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info
typedef NS_ENUM(NSInteger, FTStatus) {
    FTStatusInfo         = 0,
    FTStatusWarning,
    FTStatusError,
    FTStatusCritical,
    FTStatusOk,
};
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


@interface FTObjectBean : NSObject
///当前对象的名称，同一个分类下，对象名称如果重复，会覆盖原有数据 （必填）
@property (nonatomic, copy) NSString *name;
///当前对象的分类，分类值用户可自定义  （必填）
@property (nonatomic, copy) NSString *classStr;

///当前对象的标签，key-value 对，其中存在保留标签  （可选）
@property (nonatomic, strong) NSDictionary *tags;
///设备UUID  （可选）
@property (nonatomic, copy) NSString *deviceUUID;

@end


@interface FTLoggingBean : NSObject

///指定当前日志的来源，比如如果来源于 Ngnix，可指定为 Nginx，同一应用产生的日志 应该一样 (必填)
@property (nonatomic, copy) NSString *measurement;
///日志内容，纯文本或 JSONString 都可以 (必填)
@property (nonatomic, copy) NSString *content;

///日志来源，日志上报后，会自动将指定的指标集名作为该标签附加到该条日志上
@property (nonatomic, copy) NSString *source;
///日志所属业务或服务的名称，建议用户通过该标签指定产生该日志业务系统的名称
@property (nonatomic, copy) NSString *serviceName;
///日志所属环境，比如可用 dev 表示开发环境，prod 表示生产环境，用户可自定义
@property (nonatomic, copy) NSString *env;
///日志等级，状态，info：提示，warning：警告，error：错误，critical：严重，ok：成功，默认：info
@property (nonatomic, assign) FTStatus status;
///用于链路日志，表示当前 span 的上一个 span的 ID
@property (nonatomic, copy) NSString *parentID;
///用于链路日志，表示当前 span 操作名，也可理解为 span 名称
@property (nonatomic, copy) NSString *operationName;
///用于链路日志，表示当前 span 的 ID
@property (nonatomic, copy) NSString *spanID;
///用于链路日志，表示当前链路的 ID
@property (nonatomic, copy) NSString *traceID;
///用于链路日志，请求的响应代码，例如 200 表示请求成功
@property (nonatomic, assign) int errorCode;
///自定义标签  （可选）
@property (nonatomic, strong) NSDictionary *tags;
///自定义指标  （可选）
@property (nonatomic, strong) NSDictionary *field;
///用于链路日志，当前链路的请求响应时间，微秒为单位
@property (nonatomic, assign) int duration;
///设备UUID
@property (nonatomic, copy) NSString *deviceUUID;

@end

///上报关键事件指标集指定为 __keyevent
@interface FTKeyeventBean : NSObject

///关键事件标题  （必填）
@property (nonatomic, copy) NSString *title;

///相关事件，__eventID 需相同
@property (nonatomic, copy) NSString *eventId;
///事件的来源，保留值 datafluxTrigger 表示来自触发器
@property (nonatomic, copy) NSString *source;
///事件等级和状态，info：提示，warning：警告，error：错误，critical：严重，ok：恢复，默认：info
@property (nonatomic, assign) FTStatus status;
///触发器对应的触发规则id
@property (nonatomic, copy) NSString *ruleId;
///触发器对应的触发规则名
@property (nonatomic, copy) NSString *ruleName;
///保留值 noData 表示无数据告警
@property (nonatomic, copy) NSString *type;
///触发动作
@property (nonatomic, copy) NSString *actionType;
///用户自定义的标签
@property (nonatomic, strong) NSDictionary *tags;
///事件内容 支持 markdown 格式
@property (nonatomic, copy) NSString *content;
///事件处理建议 支持 markdown 格式
@property (nonatomic, copy) NSString *suggestion;
///事件的持续时间 单位为微秒
@property (nonatomic, assign) int duration;
///触发维度 JSONString  例如：假设新建触发规则时设置的触发维度为 host,cpu，则该值为 ["host","cpu"]
@property (nonatomic, copy) NSString *dimensions;
///设备UUID
@property (nonatomic, copy) NSString *deviceUUID;
 
@end
NS_ASSUME_NONNULL_END
