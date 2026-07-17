//
//  FTErrorDataProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/10/12.
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
typedef void (^ErrorMonitorInfoChangeBlock)(NSDictionary * _Nonnull);

@protocol FTErrorMonitorInfoWrapper <NSObject>

- (BOOL)enableMonitorMemory;
- (BOOL)enableMonitorCpu;
- (NSDictionary *)errorMonitorInfo;

@end

/// Add error data protocol
@protocol FTErrorDataDelegate <NSObject>
/// Add Error data
/// - Parameters:
///   - type: error type
///   - stateStr: app state
///   - message: error message
///   - stack: stack information
///   - property: property
///   - time: error date
- (void)addErrorWithType:(NSString *)type stateStr:(NSString *)stateStr message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property time:(long long)time;

@end


@protocol FTBacktraceReporting <NSObject>

- (NSString *)generateMainThreadBacktrace;

- (nullable NSString *)generateAllThreadsBacktrace;
@end

@protocol FTDictionaryConvertible <NSObject>


- (nullable instancetype)initWithDict:(NSDictionary *)dict;

- (NSDictionary *)toDictionary;

@end
NS_ASSUME_NONNULL_END
