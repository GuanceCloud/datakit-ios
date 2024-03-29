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
/// 按字节数截取字符串
/// - Parameter length: 字节数
-(NSString *)ft_subStringWithCharacterLength:(NSUInteger)length;
/// 清除字符串前后的空格
-(NSString *)ft_removeFrontBackBlank;
/// 数据上传行协议，Measurement 格式处理
-(NSString *)ft_replacingMeasurementSpecialCharacters;
/// 数据上传行协议，Tags key、 value ，Fields key格式处理
- (NSString *)ft_replacingSpecialCharacters;
/// 数据上传行协议，Fields value 格式处理
- (NSString *)ft_replacingFieldSpecialCharacters;
@end

NS_ASSUME_NONNULL_END
