//
//  FTUISegmentRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/29.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes;
NS_ASSUME_NONNULL_BEGIN
@interface FTUISegmentBuilder:NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int backgroundWireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong, nullable) NSNumber *selectedSegmentIndex;
@property (nonatomic, strong) NSArray *segmentTitles;
@property (nonatomic, strong) NSArray *segmentWireframeIDs;
@property (nonatomic, strong) UIColor *selectedSegmentTintColor;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end
@interface FTUISegmentRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic,copy) FTTextObfuscator textObfuscator;
-(instancetype)initWithIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
