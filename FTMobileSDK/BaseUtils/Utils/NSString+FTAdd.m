//
//  NSString+FTMd5.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/30.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "NSString+FTAdd.h"
#import <CommonCrypto/CommonDigest.h>
#import "FTLog.h"
@implementation NSString (FTAdd)
-(NSString *)ft_md5HashToLower16Bit{
    NSString *md5Str = [self ft_md5HashToLower32Bit];
    NSString *string;
    for (int i=0; i<24; i++) {
        string=[md5Str substringWithRange:NSMakeRange(8, 16)];
    }
    return string;
}
-(NSString *)ft_md5HashToUpper32Bit{
    const char *cStr = [self UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    return result;
}
-(NSString *)ft_md5HashToLower32Bit{
    const char *input = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input, (CC_LONG)strlen(input), result);
    
    NSMutableString *digest = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [digest appendFormat:@"%02x", result[i]];
    }
    
    return digest;
}
-(NSString *)ft_base64Encode{
    //1、先转换成二进制数据
    NSData *data =[self dataUsingEncoding:NSUTF8StringEncoding];
    //2、对二进制数据进行base64编码，完成后返回字符串
    return [data base64EncodedStringWithOptions:0];
}
-(NSString *)ft_base64Decode{
    //注意：该字符串是base64编码后的字符串
    //1、转换为二进制数据（完成了解码的过程）
    NSData *data=[[NSData alloc]initWithBase64EncodedString:self options:0];
    //2、把二进制数据转换成字符串
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
- (NSUInteger)ft_charactorNumber
{
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    return [self lengthOfBytesUsingEncoding:encoding];
}
-(NSString *)ft_removeFrontBackBlank{
    NSCharacterSet  *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *string = [self stringByTrimmingCharactersInSet:set];
    return string;
}
- (NSString *)ft_md5base64Encrypt{
    const char *input = [self UTF8String];//UTF8转码
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input, (CC_LONG)strlen(input), result);
    NSData *data = [NSData dataWithBytes: result length:16];
    NSString *string = [data base64EncodedStringWithOptions:0];//base64编码;
    return string;
}
@end
