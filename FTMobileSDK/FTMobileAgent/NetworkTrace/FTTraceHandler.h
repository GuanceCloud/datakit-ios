//
//  FTTraceHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/13.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// 处理单条请求 trace 处理对象
@interface FTTraceHandler : NSObject
/// 唯一标识
@property (nonatomic, copy, readwrite) NSString *identifier;
/// trace 的 span_id
@property (nonatomic, copy, readwrite) NSString *span_id;
/// trace 的 trace_id
@property (nonatomic, copy, readwrite) NSString *trace_id;

/// trace 处理对象初始化方法
/// - Parameters:
///   - url: 请求 URL
///   - identifier: 请求的唯一标识
-(instancetype)initWithUrl:(NSURL *)url identifier:(NSString *)identifier;

/// 获取 trace 添加的请求头参数
- (NSDictionary *)getTraceHeader;

@end
NS_ASSUME_NONNULL_END
