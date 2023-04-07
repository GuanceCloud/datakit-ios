//
//  FTJSONUtil.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/20.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// JSON 工具
@interface FTJSONUtil : NSObject
/**
 * @abstract
 * 把一个 dict 转成 Json字符串
 *
 * @param dict 要转化的对象
 *
 * @return 转化后得到的字符串
 */
+ (NSString *)convertToJsonData:(NSDictionary *)dict;
/**
 * @abstract
 * 把一个 Json字符串 转成 dict
 *
 * @param jsonString 要转化的 Json字符串
 *
 * @return 转化后得到的 dict
 */
+ (nullable NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;
/**
 * @abstract
 * 把一个Object转成Json字符串
 *
 * @param obj 要转化的对象Object
 *
 * @return 转化后得到的字符串
 */
- (nullable NSData *)JSONSerializeDictObject:(NSDictionary *)obj;
/**
 * @abstract
 * 把一个array转成Json字符串
 *
 * @param array 要转化的数组
 *
 * @return 转化后得到的字符串
 */
+ (NSString *)convertToJsonDataWithArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
