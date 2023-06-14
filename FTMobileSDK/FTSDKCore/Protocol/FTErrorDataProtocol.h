//
//  FTErrorDataProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/10/12.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>

/// 添加 error 数据协议
@protocol FTErrorDataDelegate <NSObject>
/// 添加 Error 数据
/// - Parameters:
///   - type: error 类型
///   - message: error 信息
///   - stack: 堆栈信息
- (void)internalErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
@end
