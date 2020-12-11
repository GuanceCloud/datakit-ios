//
//  FTBaseInfoHander.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTConstants.h"
#import <UIKit/UIKit.h>
#import "FTMobileConfig.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTBaseInfoHander : NSObject

/**
 *  @abstract
 *  FT access 签名算法
 *
 *  @return 签名后字符串
 */
+(NSString*)ft_getSignatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data;
/**
 *  @abstract
 *  tags key、value 替换特殊字符 '"'
*/
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
+(NSString *)ft_getNetworkSpanID;
+(NSString *)ft_getNetworkTraceID;
/**
 * 主线程同步执行
 */
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block;
+ (NSString *)ft_getCurrentPageName;
+ (NSString *)ft_getApplicationUUID;
+ (UIWindow *)ft_keyWindow;
+ (NSString *)itemHeatMapPathForResponder:(UIResponder *)responder;
+ (NSString *)ft_getFTstatueStr:(FTStatus)status;
+ (NSString *)ft_getFTEnvStr:(FTEnv)env;
+ (NSString *)ft_getSessionid;
+ (NSString *)ft_getUserid;
+ (void)ft_setUserid:(nullable NSString *)userid;
+ (NSString *)ft_getDictStr:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
