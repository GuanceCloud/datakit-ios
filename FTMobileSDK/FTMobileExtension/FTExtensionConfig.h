//
//  FTExtensionConfig.h
//  FTMobileExtension
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTExtensionConfig : NSObject

/// 文件共享 Group Identifier。（必须设置）
@property (nonatomic, copy) NSString *groupIdentifier;

/// 设置是否允许 SDK 打印 Debug 日志
@property (nonatomic, assign) BOOL enableSDKDebugLog;

/// 设置是否需要采集崩溃日志
@property (nonatomic, assign) BOOL enableTrackAppCrash;

/// 设置是否开启 RUM 中 http Resource 事件自动采集
@property (nonatomic, assign) BOOL enableRUMAutoTraceResource;

/// 设置是否开启自动 http 链路追踪
@property (nonatomic, assign) BOOL enableTracerAutoTrace;

/// 数据保存在 Extension 数量最大值
///
/// 默认 1000 条，达到上限时删除旧数据保存新数据
@property (nonatomic, assign) NSInteger memoryMaxCount;

/// 初始化方法，同时设置必要参数 groupIdentifier
/// - Parameter groupIdentifier: 文件共享 Group Identifier
- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier;
@end

NS_ASSUME_NONNULL_END
