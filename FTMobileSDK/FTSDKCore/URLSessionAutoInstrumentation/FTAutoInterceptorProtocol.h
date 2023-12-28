//
//  FTAutoInterceptorProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/10/27.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#ifndef FTAutoInterceptorProtocol_h
#define FTAutoInterceptorProtocol_h
#import "FTURLSessionInterceptorProtocol.h"

@protocol FTAutoInterceptorProtocol<NSObject>
@property (nonatomic, weak ,readonly) id<FTURLSessionInterceptorProtocol> interceptor;
/// 设置是否支持自动采集 rum resource 数据
@property (nonatomic, assign) BOOL enableAutoRumTrack;
/// 实现 trace 功能，给 request header 添加 trace 参数
/// - Parameter request: http 初始请求
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request;

/// 判断 URL 是否采集
/// 是否是 SDK 内部上传链接
/// - Parameter url: 需要判断的 URL
- (BOOL)isNotSDKInsideUrl:(NSURL *)url;
@end
#endif /* FTAutoInterceptorProtocol_h */
