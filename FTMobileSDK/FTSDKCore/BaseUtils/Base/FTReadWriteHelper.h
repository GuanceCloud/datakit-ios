//
//  FTReadWriteHelper.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 使用 GCD 栅栏模式实现线程安全的多读单写工具；ValueType 泛型必须遵循 NSCopying 协议
@interface FTReadWriteHelper<ValueType> : NSObject
/// 初始化
/// - Parameter value: 需要线程安全的对象
-(instancetype)initWithValue:(ValueType)value;

/// 线程安全读数据
/// - Parameter block: 读数据block块
- (void)concurrentRead:(void (^)(ValueType value))block;
/// 线程安全写数据
/// - Parameter block: 写数据block块
- (void)concurrentWrite:(void (^)(ValueType value))block;
/// 线程安全读数据，对读取的数据进行 copy，ValueType 必须遵循 NSCopying 协议，否则会崩溃
/// - Returns: 读取的数据.
- (ValueType)currentValue;
@end

NS_ASSUME_NONNULL_END
