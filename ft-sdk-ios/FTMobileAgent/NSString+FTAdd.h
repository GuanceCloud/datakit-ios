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
-(NSString *)ft_md5HashToUpper32Bit;
-(NSString *)ft_md5HashToUpper16Bit;
- (NSUInteger)charactorNumber;
/**
 *  @abstract
 *  校验 product 是否符合 只能包含英文字母、数字、中划线和下划线，最长 40 个字符，区分大小写
*/
- (BOOL)ft_verifyProductStr;
/**
 *  @abstract
 *  清除字符串前后的空格
*/
-(NSString *)ft_removeFrontBackBlank;
@end

NS_ASSUME_NONNULL_END
