//
//  FTBaseInfoHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FTBaseInfoHandler : NSObject

/**
 *  @abstract
 *  FT access 签名算法
 *
 *  @return 签名后字符串
 */
+(NSString*)signatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data;

+ (NSString *)XDataKitUUID;

+ (NSString *)sessionId;

+ (NSString *)convertToStringData:(NSDictionary *)dict;

+ (NSString *)replaceNumberCharByUrl:(NSURL *)url;

+ (NSString *)boolStr:(BOOL)isTrue;

+ (BOOL)randomSampling:(int)sampling;

#if !TARGET_OS_OSX
+(NSString *)telephonyInfo;
#endif
@end

NS_ASSUME_NONNULL_END
