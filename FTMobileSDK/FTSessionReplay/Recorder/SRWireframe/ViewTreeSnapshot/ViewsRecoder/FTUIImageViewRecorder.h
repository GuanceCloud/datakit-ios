//
//  FTUIImageViewRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRWireframesBuilder.h"
#import "FTImageDataUtils.h"
@class FTViewAttributes;
NS_ASSUME_NONNULL_BEGIN
@interface FTUIImageViewBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, assign) int imageWireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect contentFrame;
@property (nonatomic, assign) BOOL clipsToBounds;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, assign) BOOL shouldRecordImage;
@property (nonatomic, weak) id<FTImageDataProvider> imageDataProvider;
@property (nonatomic, assign) CGSize wireframeRect;
@end
@interface FTUIImageViewRecorder : NSObject<FTSRWireframesRecorder>

@end

NS_ASSUME_NONNULL_END
