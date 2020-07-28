//
//  NSString+FTMd5.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/30.
//  Copyright © 2020 hll. All rights reserved.
//

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
-(NSString *)ft_md5HashToUpper16Bit{
    NSString *md5Str = [self ft_md5HashToUpper32Bit];
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
- (NSUInteger)charactorNumber
{
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    return [self lengthOfBytesUsingEncoding:encoding];
}
- (BOOL)ft_verifyProductStr{
    BOOL result= NO;
    @try {
        NSString *regex = @"^[A-Za-z0-9_\\-]{0,40}+$";//$flow_
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
        // 字符串判断，然后BOOL值
        result = [predicate evaluateWithObject:self];
        ZYDebug(@"result : %@",result ? @"指标集命名正确" : @"验证失败");
    }@catch (NSException *exception) {
        ZYDebug(@"verifyProductStr %@",exception);
    }
    return result;
}
-(NSString *)ft_removeFrontBackBlank{
    NSCharacterSet  *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *string = [self stringByTrimmingCharactersInSet:set];
    return string;
}
@end
