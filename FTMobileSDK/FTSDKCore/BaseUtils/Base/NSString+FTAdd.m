//
//  NSString+FTMd5.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/6/30.
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
    // 1. First convert to binary data
    NSData *data =[self dataUsingEncoding:NSUTF8StringEncoding];
    //2. Base64 encode the binary data, return string after completion
    return [data base64EncodedStringWithOptions:0];
}
-(NSString *)ft_base64Decode{
    // Note: This string is a base64-encoded string
    // 1. Convert to binary data (decoding process is completed)
    NSData *data=[[NSData alloc]initWithBase64EncodedString:self options:0];
    // 2. Convert the binary data to a string
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
    if (strlen(chars) <= charLength/3 +1) {//1 complex character 3 bytes, 1 English 1 byte
        return self;
    }
    NSString *str = self;
    for (int i=0; i<self.length; i++) {
        unichar a = [self characterAtIndex:i];
        if( a >= 0x4e00 && a <= 0x9fa5){ //Check if it's a complex character
            character +=3;
        }else{
            character +=1;
        }
        if (character >= length) {//Truncate by byte count
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
    reStr = [reStr stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
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
