//
//  FTUnsupportedViewRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSRWireframesBuilder.h"
NS_ASSUME_NONNULL_BEGIN
@class FTViewAttributes;

@interface FTUnsupportedViewBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, copy) NSString *unsupportedClassName;
@end
@interface FTUnsupportedViewRecorder : NSObject<FTSRWireframesRecorder>

@end
NS_ASSUME_NONNULL_END
