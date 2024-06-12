//
//  FTUIStepperRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRWireframesBuilder.h"

@class FTViewAttributes;
NS_ASSUME_NONNULL_BEGIN
@interface FTUIStepperBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, assign) int dividerWireframeID;
@property (nonatomic, assign) int minusWireframeID;
@property (nonatomic, assign) int plusHorizontalWireframeID;
@property (nonatomic, assign) int plusVerticalWireframeID;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) CGFloat cornerRadius;
/// 是否允许 LeftSegment 点击
///  当前值已经是最小值时，`—` 不允许点击，显示灰色
///  (14,2)
@property (nonatomic, assign) BOOL isMinusEnabled;
/// 是否允许 RightSegment 点击
///  当前值已经是最大值时，`+` 不允许点击，显示灰色
///  (14,12)
@property (nonatomic, assign) BOOL isPlusEnabled;
@end
@interface FTUIStepperRecorder : NSObject<FTSRWireframesRecorder>

@end

NS_ASSUME_NONNULL_END
