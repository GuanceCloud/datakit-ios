//
//  FTUISwitchRecorder.h
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
@interface FTUISwitchBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;

@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, assign) int trackWireframeID;
@property (nonatomic, assign) int thumbWireframeID;

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isDarkMode;
@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, assign) BOOL isMasked;

@property (nullable) CGColorRef onTintColor;
@property (nullable) CGColorRef offTintColor;
@property (nullable) CGColorRef thumbTintColor;

@end
@interface FTUISwitchRecorder : NSObject<FTSRWireframesRecorder>

@end

NS_ASSUME_NONNULL_END
