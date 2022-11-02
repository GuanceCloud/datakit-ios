//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTTraceHandler;
/// 管理 trace 的类
///
/// 功能：
/// -  根据 URL 判断请求是否进行 trace 追踪
/// -  获取 trace 的请求头参数
/// -  根据 key 管理 traceHandler
@interface FTTraceManager : NSObject

/// 是否允许自动开启 trace
@property (nonatomic, assign) BOOL enableAutoTrace;

/// 单例
+ (instancetype)sharedInstance;

/// 判断 url 是否进行采集
/// - Parameter url: 采集的URL
- (BOOL)isTraceUrl:(NSURL *)url;

/// 获取 trace 的请求头参数
/// - Parameters:
///   - key: 能够确定某一请求的唯一标识
///   - url: 请求 URL
/// - Returns: trace 的请求头参数字典
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;

/// 根据 key 获取 trace 处理对象
/// - Parameter key: 请求的唯一标识
/// - Returns: 处理请求的 trace 处理对象
- (FTTraceHandler *)getTraceHandler:(NSString *)key;

/// 根据 key 删除 trace 处理对象
/// - Parameter key: 请求的唯一标识
- (void)removeTraceHandlerWithKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
