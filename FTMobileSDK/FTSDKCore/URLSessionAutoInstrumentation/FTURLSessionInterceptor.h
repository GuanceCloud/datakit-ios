//
//  FTURLSessionInterceptor.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTURLSessionInterceptorProtocol.h"
#import "FTTracerProtocol.h"
#import "FTExternalResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@class FTTraceHandler;

/// url session 的拦截器，实现 rum resource 数据的采集
@interface FTURLSessionInterceptor : NSObject<FTURLSessionInterceptorDelegate,FTExternalResourceProtocol>

/// 设置实现 trace 功能的对象
/// @param tracer 实现 trace 功能的对象
- (void)setTracer:(id<FTTracerProtocol>)tracer;

/// 授权是否开启 Trace
/// @param enable 授权许可
-(void)enableAutoTrace:(BOOL)enable;

/// 授权是否开启 linkRumData
/// @param enable 授权许可
-(void)enableLinkRumData:(BOOL)enable;

@end

NS_ASSUME_NONNULL_END
