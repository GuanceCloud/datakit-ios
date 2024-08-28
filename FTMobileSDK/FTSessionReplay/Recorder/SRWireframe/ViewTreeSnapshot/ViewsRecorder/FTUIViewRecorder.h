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
@interface FTUIViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) SemanticsOverride semanticsOverride;
-(instancetype)initWithIdentifier:(NSString *)identifier;
-(instancetype)initWithIdentifier:(NSString *)identifier semanticsOverride:(SemanticsOverride)semanticsOverride;
@end

NS_ASSUME_NONNULL_END
