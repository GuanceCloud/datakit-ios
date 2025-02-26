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
@class FTViewAttributes,FTUIImageResource;

NS_ASSUME_NONNULL_BEGIN
typedef UIColor* _Nullable(^FTTintColorProvider)(UIImageView *imageView);
typedef BOOL (^FTShouldRecordImagePredicate)(UIImageView *imageView);

@interface FTUIImageViewBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, assign) int imageWireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect contentFrame;

@property (nonatomic, strong) FTUIImageResource *imageResource;
@property (nonatomic, assign) CGRect wireframeRect;
@end
@interface FTUIImageViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) SemanticsOverride semanticsOverride;
@property (nonatomic, copy) FTShouldRecordImagePredicate shouldRecordImagePredicate;
@property (nonatomic, copy) FTTintColorProvider tintColorProvider;

@property (nonatomic, copy) NSString *identifier;
-(instancetype)initWithIdentifier:(NSString *)identifier
                tintColorProvider:(nullable FTTintColorProvider)tintColorProvider
       shouldRecordImagePredicate:(nullable FTShouldRecordImagePredicate)shouldRecordImagePredicate;
@end

NS_ASSUME_NONNULL_END
