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
/**
 * 文件共享 Group Identifier。（必须设置）
 */
@property (nonatomic, copy) NSString *groupIdentifier;

/**
 * 设置是否允许 SDK 打印 Debug 日志
 */
@property (nonatomic, assign) BOOL enableSDKDebugLog;
/**
 * 设置是否需要采集崩溃日志
 */
@property (nonatomic, assign) BOOL enableTrackAppCrash;
/**
 * 设置是否开启自动 http trace
 */
@property (nonatomic, assign) BOOL enableAutoTraceResource;

/// 初始化方法，同时设置必要参数 groupIdentifier
/// - Parameter groupIdentifier: 文件共享 Group Identifier
- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier;
@end

NS_ASSUME_NONNULL_END
