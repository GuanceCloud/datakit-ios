//
//  NSURLSessionConfiguration+FTSwizzler.h
//  FTMobileAgent
//
//  Created by hulilei on 2023/3/13.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSessionConfiguration (FTSwizzler)
+ (NSURLSessionConfiguration *)ft_defaultSessionConfiguration;
+ (NSURLSessionConfiguration *)ft_ephemeralSessionConfiguration;

@end

NS_ASSUME_NONNULL_END
