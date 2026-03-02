//
//  FTUIActivityIndicatorRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes,FTViewTreeRecorder;
NS_ASSUME_NONNULL_BEGIN

@interface FTUIActivityIndicatorBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) UIColor * backgroundColor;
@end

@interface FTUIActivityIndicatorRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end
NS_ASSUME_NONNULL_END
