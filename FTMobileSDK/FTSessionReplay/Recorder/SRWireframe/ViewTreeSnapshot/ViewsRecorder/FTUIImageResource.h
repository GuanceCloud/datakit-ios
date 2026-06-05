//
//  FTUIImageResource.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/14.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSRNodeWireframesBuilder.h"
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface FTUIImageResource : NSObject<FTSRResource>
-(instancetype)initWithImage:(UIImage *)image tintColor:(UIColor *)tintColor;
-(instancetype)initWithImage:(UIImage *)image tintColor:(nullable UIColor *)tintColor traitCollection:(nullable UITraitCollection *)traitCollection;
@end

NS_ASSUME_NONNULL_END
