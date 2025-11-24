//
//  FTSwizzle.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/28.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface  NSObject(FTSwizzle)
+ (BOOL)ft_swizzleMethod:(SEL)origSel_ withMethod:(SEL)altSel_ error:(NSError**)error_;
+ (BOOL)ft_swizzleClassMethod:(SEL)origSel_ withClassMethod:(SEL)altSel_ error:(NSError**)error_;
@end

NS_ASSUME_NONNULL_END
