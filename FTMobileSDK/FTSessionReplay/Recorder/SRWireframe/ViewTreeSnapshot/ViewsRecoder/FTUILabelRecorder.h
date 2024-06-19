//
//  FTUILabelRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRWireframesBuilder.h"

@class FTViewAttributes;
@protocol FTSRTextObfuscatingProtocol;

NS_ASSUME_NONNULL_BEGIN
@interface FTUILabelBuilder : NSObject<FTSRWireframesBuilder>
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;

@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic, strong) UIFont *font;
@property (nullable) CGColorRef textColor;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end
typedef FTUILabelBuilder* _Nullable (^FTBuilderOverride)(FTUILabelBuilder *builder);

@interface FTUILabelRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic,copy) FTTextObfuscator textObfuscator;
@property (nonatomic,copy) FTBuilderOverride builderOverride;
-(instancetype)initWithBuilderOverride:(FTBuilderOverride)builderOverride textObfuscator:(FTTextObfuscator)textObfuscator;
@end

NS_ASSUME_NONNULL_END
