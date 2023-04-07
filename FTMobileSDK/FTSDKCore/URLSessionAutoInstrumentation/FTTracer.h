//
//  FTTracer.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTTracerProtocol.h"
#import "FTEnumConstant.h"
@class FTTraceConfig;
NS_ASSUME_NONNULL_BEGIN
/// 具体实现 trace 功能，请求头添加参数实现
@interface FTTracer : NSObject<FTTracerProtocol>

/// 初始化
/// - Parameter config: trace 配置项
-(instancetype)initWithSampleRate:(int)sampleRate traceType:(NetworkTraceType)traceType;
#if FTSDKUNITTEST
-(NSUInteger)getSkywalkingSeq;
#endif

@end

NS_ASSUME_NONNULL_END
