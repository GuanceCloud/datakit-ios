//
//  NSString+FTMd5.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/30.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 字符串附加方法
@interface NSString (FTAdd)
/// 16位 MD5 小写
-(NSString *)ft_md5HashToLower16Bit;
/// 字符串 base64 编码
-(NSString *)ft_base64Encode;
/// 字符串 base64 解码
-(NSString *)ft_base64Decode;
/// utf8 编码模式下 字符串长度. 英文8位（一个字节)、中文24位(三个字节)
-(NSUInteger)ft_characterNumber;
/// 清除字符串前后的空格
-(NSString *)ft_removeFrontBackBlank;
@end

NS_ASSUME_NONNULL_END
