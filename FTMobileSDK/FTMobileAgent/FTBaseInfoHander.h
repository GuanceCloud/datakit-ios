//
//  FTBaseInfoHander.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FTTrackBean.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTBaseInfoHander : NSObject

+ (NSString *)ft_md5base64EncryptStr:(NSString *)str;
/**
 *  @abstract
 *  FT access 签名算法
 *
 *  @return 签名后字符串
 */
+(NSString*)ft_getSignatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data;
+ (id)repleacingSpecialCharactersField:(id )str;
/**
 *  @abstract
 *  tags key、value 替换特殊字符 ',' '=' ' '
*/
+ (id)repleacingSpecialCharacters:(id )str;
/**
 *  @abstract
 *  Measurement 替换特殊字符 ' ' ','
*/
+ (id)repleacingSpecialCharactersMeasurement:(id )str;
/**
 *  @abstract
 *  FTStatus 字符串转换
*/
+(NSString *)ft_getFTstatueStr:(FTStatus)status;
+(NSString *)ft_getNetworkSpanID;
+(NSString *)ft_getNetworkTraceID;
/**
 * 主线程同步执行
 */
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block;
+ (NSString *)ft_getCurrentPageName;
@end

NS_ASSUME_NONNULL_END
