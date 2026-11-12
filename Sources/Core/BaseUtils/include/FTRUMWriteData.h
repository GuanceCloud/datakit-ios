//
//  FTRUMWriteData.h
//  FTMobileSDK
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
#import "FTRUMPropertySnapshot.h"

NS_ASSUME_NONNULL_BEGIN
/// Internal write envelope. No live preset state is read while assembling it.
@interface FTRUMWriteData : NSObject
@property (nonatomic, copy, readonly) NSString *source;
@property (nonatomic, copy, readonly) NSDictionary *tags;
@property (nonatomic, copy, readonly) NSDictionary *fields;
@property (nonatomic, strong, readonly) FTRUMPropertySnapshot *context;
@property (nonatomic, copy, readonly) NSSet<NSString *> *customTagKeys;
@property (nonatomic, copy, readonly) NSSet<NSString *> *customFieldKeys;
/// Explicit native Visitor: current value at live envelope creation, or the saved request/history value.
/// nil means no native override; Browser and historical dictionaries keep their supplied identity.
@property (nonatomic, copy, nullable) NSString *visitorIDSnapshot;
@property (nonatomic, assign) long long time;
@property (nonatomic, assign) long long updateTime;
/// nil uses the writer's existing sampling/cache mode.
@property (nonatomic, copy, nullable) NSNumber *cache;
/// Explicit key sets contain names validated at collection ingress. Copy freezes mutable sets;
/// immutable sets are shared. Only missing sets are inferred from legacy metadata.
- (instancetype)initWithSource:(NSString *)source tags:(nullable NSDictionary *)tags fields:(nullable NSDictionary *)fields
                       context:(nullable FTRUMPropertySnapshot *)context
                 customTagKeys:(nullable NSSet<NSString *> *)tagKeys customFieldKeys:(nullable NSSet<NSString *> *)fieldKeys
                          time:(long long)time;
@end
NS_ASSUME_NONNULL_END
