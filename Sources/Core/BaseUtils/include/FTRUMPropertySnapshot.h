//
//  FTRUMPropertySnapshot.h
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

NS_ASSUME_NONNULL_BEGIN
/// Immutable preset values and provenance read atomically on the RUM path.
@interface FTRUMPropertySnapshot : NSObject
@property (nonatomic, copy, readonly) NSDictionary *tags;
@property (nonatomic, copy, readonly) NSSet<NSString *> *customKeys;
- (instancetype)initWithTags:(nullable NSDictionary *)tags customKeys:(nullable NSSet<NSString *> *)customKeys;
+ (instancetype)snapshotWithLegacyTags:(nullable NSDictionary *)tags;
- (NSDictionary *)legacyTags;
- (FTRUMPropertySnapshot *)snapshotBySettingSystemValue:(nullable id)value forKey:(NSString *)key;
@end

/// Own collection input across queues without changing NSNumber types or units.
FOUNDATION_EXPORT NSDictionary *FTRUMCopyDictionary(NSDictionary * _Nullable dictionary);
/// Decode only explicit provenance; never guess from the payload's keys.
FOUNDATION_EXPORT NSSet<NSString *> *FTRUMDecodeCustomKeys(id _Nullable value);
/// Merge values and provenance with identical last-writer-wins semantics.
FOUNDATION_EXPORT void FTRUMMergeProperties(NSMutableDictionary *values, NSMutableSet<NSString *> *customKeys,
                                           NSDictionary * _Nullable incoming, NSSet<NSString *> * _Nullable incomingKeys);
FOUNDATION_EXPORT void FTRUMSetSystemProperty(NSMutableDictionary *values, NSMutableSet<NSString *> *customKeys,
                                             NSString *key, id _Nullable value);
FOUNDATION_EXPORT void FTRUMEncodeCustomKeys(NSMutableDictionary *tags, NSDictionary *fields,
                                            NSSet<NSString *> * _Nullable tagKeys, NSSet<NSString *> * _Nullable fieldKeys);
NS_ASSUME_NONNULL_END
