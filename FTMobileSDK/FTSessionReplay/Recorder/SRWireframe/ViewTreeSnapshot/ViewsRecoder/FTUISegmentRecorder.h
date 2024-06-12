//
//  FTUISegmentRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/29.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRWireframesBuilder.h"

@class FTViewAttributes;
NS_ASSUME_NONNULL_BEGIN
@interface FTUISegmentBuilder:NSObject<FTSRWireframesBuilder>
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong) NSNumber *selectedSegmentIndex;
@property (nonatomic, strong) NSArray *segmentTitles;
@property (nonatomic, strong) NSArray *segmentWireframeIDs;
@property (nullable) CGColorRef selectedSegmentTintColor;
@end
@interface FTUISegmentRecorder : NSObject<FTSRWireframesRecorder>

@end

NS_ASSUME_NONNULL_END
