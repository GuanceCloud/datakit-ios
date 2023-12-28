//
//  FTLoggerDataWriteProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/26.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#ifndef FTLoggerDataWriteProtocol_h
#define FTLoggerDataWriteProtocol_h
#import "FTEnumConstant.h"
NS_ASSUME_NONNULL_BEGIN
/// RUM 数据写入接口
@protocol FTLoggerDataWriteProtocol <NSObject>

/// Logger 数据写入
/// - Parameters:
///   - content: 日志内容
///   - status: 日志状态
///   - tags: 属性
///   - field: 指标
///   - time: 数据产生时间戳(ns)
-(void)logging:(NSString *)content status:(LogStatus)status tags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time;
@end
NS_ASSUME_NONNULL_END

#endif /* FTLoggerDataWriteProtocol_h */
