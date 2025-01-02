//
//  FTTraceContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/31.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTTraceContext;
/// 支持通过 url 判断是否进行自定义 trace,确认拦截后，返回 TraceContext，不拦截返回 nil
typedef FTTraceContext*_Nullable(^FTTraceInterceptor)(NSURL * _Nullable url);
NS_ASSUME_NONNULL_BEGIN
/// 自定义 Trace 的内容
@interface FTTraceContext: NSObject
/// traceId，用于关联 rum
@property (nonatomic, copy) NSString *traceId;
/// spanId，用于关联 rum
@property (nonatomic, copy) NSString *spanId;
/// trace 数据，SDK 收到回调后会添加至 request.allHTTPHeaderFields 中
@property (nonatomic, strong) NSDictionary<NSString*,NSString*>*traceHeader;

@end

NS_ASSUME_NONNULL_END
