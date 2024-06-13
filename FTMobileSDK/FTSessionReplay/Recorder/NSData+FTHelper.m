//
//  NSData+FTHelper.m
//  FTMobileSDK
//
//  Created by hulilei on 2022/12/12.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "NSData+FTHelper.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (FTHelper)
- (NSString *)ft_md5HashChecksum{
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(self.bytes, (CC_LONG)[self length], result);
    NSMutableString *digest = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [digest appendFormat:@"%02x", result[i]];
    }
    return digest;
}
- (NSString *)ft_imageDataToSting{
    NSString *str = [self
                      base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];;
    return str;
}
@end
