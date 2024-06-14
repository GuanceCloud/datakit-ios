//
//  FTUIViewRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRWireframesBuilder.h"

@class FTViewAttributes;
NS_ASSUME_NONNULL_BEGIN

@interface FTUIViewBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@end
@interface FTUnsupportedBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, copy) NSString *label;
@end
@interface FTUIViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) SemanticsOverride semanticsOverride;
-(instancetype)initWithSemanticsOverride:(SemanticsOverride)semanticsOverride;
@end

NS_ASSUME_NONNULL_END
