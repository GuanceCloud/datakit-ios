//
//  FTLongTaskEvent.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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
/// Immutable internal collection result. All time values are nanoseconds.
/// Effective duration can differ from the span between event boundaries.
@interface FTLongTaskEvent : NSObject
@property (nonatomic, copy, readonly) NSString *stack;
@property (nonatomic, assign, readonly) long long startTimeNs;
@property (nonatomic, assign, readonly) long long endTimeNs;
@property (nonatomic, assign, readonly) long long durationNs;
/// Frozen at worker End for automatic collection; includes lifecycle changes during worker delays.
/// nil preserves explicit/manual event behavior.
@property (nonatomic, copy, readonly, nullable) NSString *appState;
- (instancetype)initWithStack:(NSString *)stack startTimeNs:(long long)startTimeNs
                   endTimeNs:(long long)endTimeNs durationNs:(long long)durationNs;
- (instancetype)initWithStack:(NSString *)stack startTimeNs:(long long)startTimeNs
                   endTimeNs:(long long)endTimeNs durationNs:(long long)durationNs appState:(nullable NSString *)appState;
@end
NS_ASSUME_NONNULL_END
