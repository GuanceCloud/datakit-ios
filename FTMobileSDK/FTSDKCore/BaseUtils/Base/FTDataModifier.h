//
//  FTDataModifier.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/5/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 字段替换，适合全局字段替换场景，如果期望逐条分析，实现条数据的替换，请求使用  FTLineDataModifier
/// - Parameters:
///   - key: 字段名
///   - value: 字段值（原始值）
///   - return: 新的值，如果不修改就返回原始值；返回 nil 表示不做更改
typedef id _Nullable(^FTDataModifier)(NSString * _Nonnull key,id _Nonnull value);


/// 可以针对某一行进行判断，再决定是否需要替换某一个数值
/// 修改逻辑，只返回被修改的 key-value 对
/// - Parameters:
///   - measurement: 测量名
///   - data: 合并后的 key-value 对
///   - return: 被修改过的键值对（返回 nil 或空字典均为不更改）
typedef NSDictionary<NSString *,id> *_Nullable (^FTLineDataModifier)(NSString * _Nonnull measurement,NSDictionary<NSString *,id> * _Nonnull data);
