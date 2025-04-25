//
//  FTUIProgressViewRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"
NS_ASSUME_NONNULL_BEGIN
@class FTViewAttributes,FTViewTreeRecorder;

@interface FTUIProgressViewBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, assign) int progressTrackWireframeID;
@property (nonatomic, assign) float progress;
@property (nonatomic, strong) UIColor * progressTintColor;
@property (nonatomic, strong) UIColor * backgroundColor;
@end
@interface FTUIProgressViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

NS_ASSUME_NONNULL_END
