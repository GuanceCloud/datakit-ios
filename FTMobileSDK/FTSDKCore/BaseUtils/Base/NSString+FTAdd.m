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
@implementation NSString (FTAdd)
-(NSString *)ft_md5HashToLower16Bit{
    NSString *md5Str = [self ft_md5HashToLower32Bit];
    NSString *string;
    for (int i=0; i<24; i++) {
        string=[md5Str substringWithRange:NSMakeRange(8, 16)];
    }
    return string;
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
- (NSUInteger)ft_characterNumber{
    return [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}
- (NSString *)ft_subStringWithCharacterLength:(NSUInteger)length{
    if (!self) return nil;
    NSUInteger character = 0;
    const char *chars = [self cStringUsingEncoding:NSUTF8StringEncoding];
    NSUInteger charLength = length;
    if (strlen(chars) <= charLength/3 +1) {//1个汉字或中文字符3个字节，1个英文1个字节
        return self;
    }
    NSString *str = self;
    for (int i=0; i<self.length; i++) {
        unichar a = [self characterAtIndex:i];
        if( a >= 0x4e00 && a <= 0x9fa5){ //判断是否为中文
            character +=3;
        }else{
            character +=1;
        }
        if (character >= length) {//按字数截取
            if (character == length) {
                str = [str substringToIndex:i+1];
            }else{
                str = [str substringToIndex:i];
            }
//            str = [str stringByAppendingString:@"..."];
            break;
        }
    }
    return str;
}
-(NSString *)ft_removeFrontBackBlank{
    NSCharacterSet  *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *string = [self stringByTrimmingCharactersInSet:set];
    return string;
}
- (NSString *)ft_replacingMeasurementSpecialCharacters{
    NSString *reStr = [self stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    reStr = [reStr stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
    reStr = [reStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ " options:NSLiteralSearch range:NSMakeRange(0, reStr.length)];
    return reStr;
}
- (NSString *)ft_replacingSpecialCharacters{
    NSString *reStr = [self stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    reStr =[reStr stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
    reStr =[reStr stringByReplacingOccurrencesOfString:@"=" withString:@"\\="];
    reStr =[reStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ " options:NSLiteralSearch range:NSMakeRange(0, reStr.length)];
    return reStr;
}
- (NSString *)ft_replacingFieldSpecialCharacters{
    NSString *reStr = [self stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    reStr = [reStr stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return reStr;
}
@end
