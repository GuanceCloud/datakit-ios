//
//  NSData+FTHelper.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/12/12.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (FTHelper)
- (NSString *)ft_md5HashChecksum;
- (NSString *)ft_imageDataToSting;

@end

NS_ASSUME_NONNULL_END
