//
//  FTUISwitchRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes, FTSRColorSnapshot;
NS_ASSUME_NONNULL_BEGIN
@interface FTUISwitchBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;

@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, assign) int trackWireframeID;
@property (nonatomic, assign) int thumbWireframeID;

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isDarkMode;
@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, assign) BOOL isMasked;

@property (nonatomic, strong, nullable) FTSRColorSnapshot * onTintColor;
@property (nonatomic, strong, nullable) FTSRColorSnapshot * offTintColor;
@property (nonatomic, strong, nullable) FTSRColorSnapshot * thumbTintColor;

@end
@interface FTUISwitchRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;

@end

NS_ASSUME_NONNULL_END
