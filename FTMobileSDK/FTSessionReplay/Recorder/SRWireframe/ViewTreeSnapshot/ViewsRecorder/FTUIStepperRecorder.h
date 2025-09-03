//
//  FTUIStepperRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes;
NS_ASSUME_NONNULL_BEGIN
@interface FTUIStepperBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, assign) int dividerWireframeID;
@property (nonatomic, assign) int minusWireframeID;
@property (nonatomic, assign) int plusHorizontalWireframeID;
@property (nonatomic, assign) int plusVerticalWireframeID;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) CGFloat cornerRadius;
/// Whether LeftSegment click is allowed
///  When current value is at minimum, `—` is not clickable, displays gray
///  (14,2)
@property (nonatomic, assign) BOOL isMinusEnabled;
/// Whether RightSegment click is allowed
///  When current value is at maximum, `+` is not clickable, displays gray
///  (14,12)
@property (nonatomic, assign) BOOL isPlusEnabled;
@end
@interface FTUIStepperRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;

@end

NS_ASSUME_NONNULL_END
