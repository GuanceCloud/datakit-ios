//
//  NSString+FTMd5.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/6/30.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// String extension methods
@interface NSString (FTAdd)
/// 16-bit MD5 lowercase
-(NSString *)ft_md5HashToLower16Bit;
/// String base64 encoding
-(NSString *)ft_base64Encode;
/// String base64 decoding
-(NSString *)ft_base64Decode;
/// String length in utf8 encoding mode. English 8 bits (one byte), complex character 24 bits (three bytes)
-(NSUInteger)ft_characterNumber;
/// Truncate string by byte count
/// - Parameter length: byte count
-(NSString *)ft_subStringWithCharacterLength:(NSUInteger)length;
/// Remove spaces before and after string
-(NSString *)ft_removeFrontBackBlank;
/// Data upload line protocol, Measurement format processing
-(NSString *)ft_replacingMeasurementSpecialCharacters;
/// Data upload line protocol, Tags key, value, Fields key format processing
- (NSString *)ft_replacingSpecialCharacters;
/// Data upload line protocol, Fields value format processing
- (NSString *)ft_replacingFieldSpecialCharacters;
@end

NS_ASSUME_NONNULL_END
