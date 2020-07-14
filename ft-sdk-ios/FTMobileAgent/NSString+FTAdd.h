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
@end

NS_ASSUME_NONNULL_END
