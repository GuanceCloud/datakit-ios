//
//  FTViewAttributes.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTViewTreeSnapshot.h"
#import <UIKit/UIKit.h>
#import "FTImageDataUtils.h"
#import "FTSRViewID.h"
#import "FTSRTextObfuscatingFactory.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTSRContext : NSObject
@property (nonatomic, strong) FTSRTextObfuscatingFactory *privacy;
@property (nonatomic, copy) NSString *applicationID;
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *viewID;
@property (nonatomic, strong) NSDate *date;
@end

@interface FTViewAttributes : NSObject
@property (nonatomic, assign) CGRect frame;
@property (nullable) CGColorRef backgroundColor;
@property (nullable) CGColorRef layerBorderColor;
@property (nonatomic, assign) CGFloat layerBorderWidth;
@property (nonatomic, assign) CGFloat layerCornerRadius;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) BOOL  isHidden;
@property (nonatomic, assign) CGSize intrinsicContentSize;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL hasAnyAppearance;
@property (nonatomic, assign) BOOL isTranslucent;

-(instancetype)initWithFrameInRootView:(CGRect)frame view:(UIView *)view;
@end


NS_ASSUME_NONNULL_END
