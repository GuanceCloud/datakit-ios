//
//  FTGlobalRumManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@class  FTRUMManager,FTRumConfig;

/// 管理 RUM 的类，用于开启 RUM 各项数据的采集
@interface FTGlobalRumManager : NSObject
/// 处理 RUM 数据的对象
@property (nonatomic, strong) FTRUMManager *rumManager;

/// 单例
+ (instancetype)sharedInstance;

/// 设置 rum 配置项
/// - Parameter rumConfig: rum 配置项
- (void)setRumConfig:(FTRumConfig *)rumConfig writer:(id <FTRUMDataWriteProtocol>)writer;

/// 关闭单例
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
