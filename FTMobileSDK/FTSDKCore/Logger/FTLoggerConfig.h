//
//  FTLoggerConfig.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
///事件等级和状态，默认：FTStatusInfo
typedef NS_ENUM(NSInteger, FTLogStatus) {
    /// 提示
    FTStatusInfo         = 0,
    /// 警告
    FTStatusWarning,
    /// 错误
    FTStatusError,
    /// 严重
    FTStatusCritical,
    /// 恢复
    FTStatusOk,
};
/// 日志废弃策略
typedef NS_ENUM(NSInteger, FTLogCacheDiscard)  {
    /// 默认，当日志数据数量大于最大值（5000）时，新数据不进行写入
    FTDiscard,
    /// 当日志数据大于最大值时,废弃旧数据
    FTDiscardOldest
};
NS_ASSUME_NONNULL_BEGIN
/// logger 功能配置项
@interface FTLoggerConfig : NSObject
/// 禁用 new 初始化
+ (instancetype)new NS_UNAVAILABLE;
/// 日志废弃策略
@property (nonatomic, assign) FTLogCacheDiscard  discardType;
/// 采样配置，属性值：0至100，100则表示百分百采集，不做数据样本压缩。
@property (nonatomic, assign) int samplerate;
/// 是否将 logger 数据与 rum 关联
@property (nonatomic, assign) BOOL enableLinkRumData;
/// 是否上传自定义 log
@property (nonatomic, assign) BOOL enableCustomLog;
/// 是否将自定义日志在控制台打印
@property (nonatomic, assign) BOOL printCustomLogToConsole;
/// 日志最大缓存量, 最低设置为 1000  默认 5000
@property (nonatomic, assign) int logCacheLimitCount;
/// 设置需要采集的日志等级，默认为全采集
///
/// 例:1.采集日志等级为 Info 与 Error 的自定义日志则设置为
/// @[@(FTStatusInfo),@(FTStatusError)] 或 @[@0,@1]
/// 2.采集日志等级包含自定义等级 如采集 "customLevel" 与 FTStatusError 则设置为
/// @[@"customLevel",@(FTStatusError)]
@property (nonatomic, copy) NSArray *logLevelFilter;
/// logger 全局 tag
@property (nonatomic, copy) NSDictionary<NSString*,NSString*> *globalContext;
@end

NS_ASSUME_NONNULL_END
