//
//  NSDictionary+FTCopyProperties.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/21.
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

@interface NSDictionary (FTCopyProperties)
- (NSDictionary *)ft_deepCopy;
- (BOOL)ft_hasValidValueForKey:(NSString *)key;
@end

@interface NSObject (FTSafeDictionary)
+ (NSDictionary *)ft_normalizedDictionaryWithObject:(nullable id)object;
@end

@interface FTLinePropertyBag : NSObject
@property (nonatomic, copy, readonly) NSDictionary *tags;
@property (nonatomic, copy, readonly) NSDictionary *fields;
@property (nonatomic, copy, readonly) NSDictionary *mergedDictionary;
- (instancetype)initWithTags:(nullable id)tags fields:(nullable id)fields;
- (FTLinePropertyBag *)bagByApplyingChangedValues:(nullable id)changedValues;
@end

NS_ASSUME_NONNULL_END
