//
//  UIImage+FTSRIdentifier.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/17.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (FTSRIdentifier)
@property(nonatomic, copy) NSString *srIdentifier;
- (NSData *)ft_pngDataWithTintColor:(nullable UIColor *)tintColor;
@end

NS_ASSUME_NONNULL_END
