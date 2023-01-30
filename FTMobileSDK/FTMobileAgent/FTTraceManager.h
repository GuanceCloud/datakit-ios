//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/11/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// 管理 trace 的类
///
/// 功能：
/// -  根据 URL 判断请求是否进行 trace 追踪
/// -  获取 trace 的请求头参数
/// -  根据 key 管理 traceHandler
@interface FTTraceManager : NSObject
/// 单例
+ (instancetype)sharedInstance;
/// 获取 trace 的请求头参数 (已废弃)
/// - Parameters:
///   - key: 能够确定某一请求的唯一标识
///   - url: 请求 URL
/// - Returns: trace 的请求头参数字典
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url DEPRECATED_MSG_ATTRIBUTE("已过时，请使用 [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:url:] 替换");
@end

NS_ASSUME_NONNULL_END
