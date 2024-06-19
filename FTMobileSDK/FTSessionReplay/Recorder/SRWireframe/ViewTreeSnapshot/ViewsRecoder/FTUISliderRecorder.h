//
//  FTUISliderRecorder.h
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
@interface FTUISliderBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;

@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, assign) int minTrackWireframeID;
@property (nonatomic, assign) int maxTrackWireframeID;
@property (nonatomic, assign) int thumbWireframeID;

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isMasked;

@property (nonatomic, assign) float min;
@property (nonatomic, assign) float max;
@property (nonatomic, assign) float value;

@property (nullable) CGColorRef minTrackTintColor;
@property (nullable) CGColorRef maxTrackTintColor;
@property (nullable) CGColorRef thumbTintColor;

@end
@interface FTUISliderRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;

@end

NS_ASSUME_NONNULL_END
