//
//  FTJSONUtil.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/20.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTJSONUtil : NSObject

/**
 *  @abstract
 *  把一个Object转成Json字符串
 *
 *  @param obj 要转化的对象Object
 *
 *  @return 转化后得到的字符串
 */
- (NSData *)JSONSerializeDictObject:(NSDictionary *)obj;
@end

NS_ASSUME_NONNULL_END
