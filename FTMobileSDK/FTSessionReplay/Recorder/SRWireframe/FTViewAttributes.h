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
#import "FTSRViewID.h"
#import "FTSRTextObfuscatingFactory.h"
#import "FTSessionReplayPrivacyOverrides+Extension.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTSRContext : NSObject
@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;
@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;
@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;
@property (nonatomic, copy) NSString *applicationID;
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *viewID;
@property (nonatomic, strong) NSDate *date;
@end

@interface FTViewAttributes : NSObject
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGRect clip;
@property (nonatomic, strong) UIColor * backgroundColor;
@property (nullable) CGColorRef layerBorderColor;
@property (nonatomic, assign) CGFloat layerBorderWidth;
@property (nonatomic, assign) CGFloat layerCornerRadius;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) BOOL  isHidden;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL hasAnyAppearance;
@property (nonatomic, assign) BOOL isTranslucent;
@property (nonatomic, strong, nullable) NSNumber *imagePrivacy;
@property (nonatomic, strong, nullable) NSNumber *textAndInputPrivacy;
@property (nonatomic, assign) BOOL hide;

-(instancetype)initWithView:(UIView *)view frameInRootView:(CGRect)frame clip:(CGRect)clip overrides:(PrivacyOverrides *)overrides;
-(FTTextAndInputPrivacyLevel)resolveTextAndInputPrivacyLevel:(FTSRContext *)context;
-(FTImagePrivacyLevel)resolveImagePrivacyLevel:(FTSRContext *)context;

@end


NS_ASSUME_NONNULL_END
