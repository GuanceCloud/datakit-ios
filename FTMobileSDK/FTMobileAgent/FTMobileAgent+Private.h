//
//  FTMobileAgent+Private.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/14.
//  Copyright © 2020 hll. All rights reserved.
//

#ifndef FTMobileAgent_Private_h
#define FTMobileAgent_Private_h


#import "FTMobileAgent.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FTRecordModel,FTPresetProperty,FTRUMManager;


@interface FTMobileAgent (Private)
/// 预置属性
@property (nonatomic, strong) FTPresetProperty *presetProperty;

/// 内部 RUM 数据写入
/// - Parameters:
///   - type: 数据类型,View、Action、Resource、Error、LongTask
///   - terminal: 终端
///   - tags: 标签
///   - fields: 指标
- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields;

/// 内部 RUM 数据写入
/// - Parameters:
///   - type: 数据类型,View、Action、Resource、Error、LongTask
///   - terminal: 终端
///   - tags: 标签
///   - fields: 指标
///   - tm: 时间戳
- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;


/// 重置 SDK （测试用例）
-(void)resetInstance;

/// 现有数据同步写入 （测试用例）
- (void)syncProcess;
@end
#endif /* FTMobileAgent_Private_h */
