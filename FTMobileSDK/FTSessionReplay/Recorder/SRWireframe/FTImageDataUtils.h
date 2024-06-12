//
//  FTImageDataUtils.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTImageDataProvider <NSObject>
- (NSString *)imageContentBase64String:(UIImage *)image;
- (NSString *)imageContentBase64String:(UIImage *)image tintColor:(nullable UIColor *)color;

@end
@interface FTImageDataUtils : NSObject<FTImageDataProvider>

@end

NS_ASSUME_NONNULL_END
