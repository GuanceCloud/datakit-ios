//
//  FTExternalResourceProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/11/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRumResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN

/// 处理用户自定义处理 HTTP Resource 数据的协议
@protocol FTExternalResourceProtocol <NSObject,FTRumResourceProtocol>

/// 获取 trace 需要添加的请求头
/// - Parameters:
///   - key: 请求标识
///   - url: 请求 URL
- (nullable NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
