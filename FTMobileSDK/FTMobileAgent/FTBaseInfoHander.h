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
+(NSString*)signatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data;

/**
 * 主线程同步执行
 */
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block;
+ (NSString *)currentPageName;
+ (NSString *)applicationUUID;
+ (UIWindow *)keyWindow;
+ (NSString *)itemHeatMapPathForResponder:(UIResponder *)responder;
/**
 *  @abstract
 *  FTStatus 字符串转换
*/
+ (NSString *)statusStrWithStatus:(FTStatus)status;
+ (NSString *)envStrWithEnv:(FTEnv)env;
+ (NSString *)networkTraceTypeStrWithType:(FTNetworkTraceType)type;
+ (NSString *)XDataKitUUID;
+ (NSString *)sessionId;
+ (NSString *)userId;
+ (void)setUserId:(nullable NSString *)userid;
+ (NSString *)convertToStringData:(NSDictionary *)dict;

+ (NSString *)replaceNumberCharByUrl:(NSURL *)url;
+ (NSString *)getIPWithHostName:(const NSString *)hostName;
+ (NSString *)boolStr:(BOOL)isTrue;

+ (BOOL)randomSampling:(int)sampling;
@end

NS_ASSUME_NONNULL_END
