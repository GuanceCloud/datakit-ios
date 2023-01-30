//
//  FTRecordModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// 数据存储模型
@interface FTRecordModel : NSObject

/// 数据采集时的时间（纳秒级时间戳）
@property (nonatomic, assign) long long tm;
/// 记录的操作数数据
@property (nonatomic, strong) NSString *data;
/// 数据类型，\RUM\Logging
@property (nonatomic, strong) NSString *op;

/// 初始化方法
/// - Parameters:
///   - source: 数据来源
///   - op: 数据类型
///   - tags: tag 类型数据
///   - fields: field 类型数据
///   - tm: 数据采集时的时间（纳秒级时间戳）
-(instancetype)initWithSource:(NSString *)source op:(NSString *)op tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
@end

NS_ASSUME_NONNULL_END
