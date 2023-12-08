//
//  FTLogger+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/26.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTLogger.h"
#import "FTEnumConstant.h"
#import "FTLoggerDataWriteProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTLogger ()
/// 在SDK启动时调用，开启 Logger
/// - Parameters:
///   - enable: 是否需要输出到控制台
///   - enableCustomLog: 是否采集自定义日志
///   - filter: 日志过滤规则
///   - sampletRate: 采集率
///   - writer: 数据写入对象
+ (void)startWithEnablePrintLogsToConsole:(BOOL)enable enableCustomLog:(BOOL)enableCustomLog logLevelFilter:(NSArray<NSNumber*>*)filter sampleRate:(int)sampletRate writer:(id<FTLoggerDataWriteProtocol>)writer;

/// 日志传入
/// - Parameters:
///   - message: 日志内容，可为 json 字符串
///   - status: 等级和状态
///   - property: 自定义属性(可选)
- (void)log:(NSString *)message
     status:(LogStatus)status
   property:(nullable NSDictionary *)property;

/// 同步执行处理日志的队列
- (void)syncProcess;
@end

NS_ASSUME_NONNULL_END
