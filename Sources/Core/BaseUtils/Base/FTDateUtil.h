//
//  FTDateUtil.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/24.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

@interface FTDateUtil : NSObject
+ (NSDate *)date;
/// Returns the absolute timestamp, which has no defined reference point or unit as it is platform dependent.（Nanosecond-level time）
+ (uint64_t)systemTime;
+ (NSTimeInterval)systemUptime;
+ (NSDate *)processStartTimestamp;
@end

NS_ASSUME_NONNULL_END
