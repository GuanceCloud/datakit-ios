//
//  FTRUMNetworkSettledMetric.h
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
@class FTRUMAppStateHistory;
NS_ASSUME_NONNULL_BEGIN

/// Immutable original collection context; never derived from writer-modified fields.
@interface FTRUMNetworkSettledResourceParams : NSObject
@property (nonatomic, copy, readonly, nullable) NSString *resourceURL;
@property (nonatomic, copy, readonly) NSString *viewName;
@property (nonatomic, assign, readonly) long long timeSinceViewStartNs;
- (instancetype)initWithURL:(nullable NSString *)URL viewName:(NSString *)viewName offsetNs:(long long)offsetNs;
@end

/// Internal extension point, fixed for a View. Called on rumQueue with evolving original data.
@protocol FTRUMNetworkSettledResourcePredicate <NSObject>
- (BOOL)isInitialResource:(FTRUMNetworkSettledResourceParams *)params;
@end

@interface FTRUMTimeBasedNetworkSettledPredicate : NSObject <FTRUMNetworkSettledResourcePredicate>
- (instancetype)initWithThresholdNs:(long long)thresholdNs;
@end

/// Owns network lifecycle and completed batches. Queries never advance batch state.
@interface FTRUMNetworkSettledMetric : NSObject
- (instancetype)initWithStartNs:(long long)startNs viewName:(NSString *)viewName predicate:(nullable id<FTRUMNetworkSettledResourcePredicate>)predicate;
- (void)startResourceWithKey:(NSString *)key startNs:(long long)startNs URL:(nullable NSString *)URL;
- (void)updateResourceWithKey:(NSString *)key startNs:(long long)startNs URL:(nullable NSString *)URL;
- (void)completeResourceWithKey:(NSString *)key endNs:(long long)endNs;
- (void)dropResourceWithKey:(NSString *)key;
- (void)moveStartEarlierTo:(long long)startNs;
- (nullable NSNumber *)valueWithHistory:(nullable FTRUMAppStateHistory *)history;
@end
NS_ASSUME_NONNULL_END
