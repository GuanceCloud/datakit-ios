//
//  FTReadWriteHelper.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/7/7.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thread-safe multiple-read single-write tool implemented using GCD barrier mode; ValueType generic must conform to NSCopying protocol
@interface FTReadWriteHelper<ValueType> : NSObject
/// Initialize
/// - Parameter value: Object that needs thread safety
-(instancetype)initWithValue:(ValueType)value;

/// Thread-safe read data
/// - Parameter block: Read data block
- (void)concurrentRead:(void (^)(ValueType value))block;
/// Thread-safe write data
/// - Parameter block: Write data block
- (void)concurrentWrite:(void (^)(ValueType value))block;
/// Thread-safe read data, copy the read data, ValueType must conform to NSCopying protocol, otherwise it will crash
/// - Returns: Read data.
- (ValueType)currentValue;
@end

NS_ASSUME_NONNULL_END
