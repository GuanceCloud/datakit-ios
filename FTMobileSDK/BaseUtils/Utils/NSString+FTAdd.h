//
//  NSString+FTMd5.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/30.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (FTAdd)
-(NSString *)ft_md5HashToLower16Bit;
-(NSUInteger)ft_characterNumber;
-(NSString *)ft_base64Encode;
-(NSString *)ft_base64Decode;

/**
 *  @abstract
 *  清除字符串前后的空格
*/
-(NSString *)ft_removeFrontBackBlank;
/**
 *  @abstract
 *  Content-MD5 加密方法
*/
- (NSString *)ft_md5base64Encrypt;
@end

NS_ASSUME_NONNULL_END
