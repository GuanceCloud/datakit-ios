//
//  FTJSONUtil.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/10/20.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

/// JSON Utility
@interface FTJSONUtil : NSObject
/**
 * @abstract
 * Convert a dict to a JSON string
 *
 * @param dict The object to be converted
 *
 * @return The resulting string after conversion
 */
+ (nullable NSString *)convertToJsonData:(NSDictionary *)dict;
/**
 * @abstract
 * Convert a JSON string to a dict
 *
 * @param jsonString The JSON string to be converted
 *
 * @return The resulting dict after conversion
 */
+ (nullable NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;

/**
 * @abstract
 * Convert a JSON string to an array
 *
 * @param jsonString The JSON string to be converted
 *
 * @return The resulting array after conversion
 */
+ (nullable NSArray *)arrayWithJsonString:(NSString *)jsonString;
/**
 * @abstract
 * Convert an Object to a JSON string
 *
 * @param obj The object to be converted
 *
 * @return The resulting string after conversion
 */
+ (nullable NSData *)JSONSerializeDictObject:(NSDictionary *)obj;
/**
 * @abstract
 * Convert a Foundation object to a JSON string
 *
 * @param object The object to be converted
 *
 * @return The resulting string after conversion
 */
+ (nullable NSString *)convertToJsonDataWithObject:(id)object;

/// Safety protection, convert an object to an object that can be converted to a JSON string
/// @param obj The object to be converted
+ (nullable id)JSONSerializableObject:(id)obj;
@end

NS_ASSUME_NONNULL_END
