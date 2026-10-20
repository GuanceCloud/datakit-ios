//
//  FTRUMViewTimingPredicates.h
//  FTMobileAgent
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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
/// Immutable Action inputs, captured before writer modifiers run.
@interface FTRUMNextViewActionParams : NSObject
@property (nonatomic, copy, readonly) NSString *actionType;
@property (nonatomic, copy, readonly) NSString *actionName;
@property (nonatomic, assign, readonly) long long timeToNextViewNs;
@property (nonatomic, copy, readonly) NSString *nextViewName;
- (instancetype)initWithType:(NSString *)type name:(NSString *)name gapNs:(long long)gapNs nextViewName:(NSString *)nextViewName;
@end

/// Custom INV eligibility rule. Must be deterministic and nonblocking; called on a background queue.
@protocol FTRUMNextViewActionPredicate <NSObject>
- (BOOL)isLastAction:(FTRUMNextViewActionParams *)params;
@end

/// Default: click Actions within an inclusive three seconds. Threshold uses nanoseconds.
@interface FTRUMTimeBasedNextViewActionPredicate : NSObject <FTRUMNextViewActionPredicate>
- (instancetype)initWithMaxTimeNs:(long long)maxTimeNs;
@end

/// Immutable original collection context; never derived from writer-modified fields.
@interface FTRUMNetworkSettledResourceParams : NSObject
@property (nonatomic, copy, readonly, nullable) NSString *resourceURL;
@property (nonatomic, copy, readonly) NSString *viewName;
@property (nonatomic, assign, readonly) long long timeSinceViewStartNs;
- (instancetype)initWithURL:(nullable NSString *)URL viewName:(NSString *)viewName offsetNs:(long long)offsetNs;
@end

/// Custom TNS eligibility rule. Called on a background queue with evolving original data.
/// Implementations must be deterministic and nonblocking.
@protocol FTRUMNetworkSettledResourcePredicate <NSObject>
- (BOOL)isInitialResource:(FTRUMNetworkSettledResourceParams *)params;
@end

/// Default: Resource starts within inclusive [0, 100ms]. Threshold uses nanoseconds.
@interface FTRUMTimeBasedNetworkSettledPredicate : NSObject <FTRUMNetworkSettledResourcePredicate>
- (instancetype)initWithThresholdNs:(long long)thresholdNs;
@end

NS_ASSUME_NONNULL_END
