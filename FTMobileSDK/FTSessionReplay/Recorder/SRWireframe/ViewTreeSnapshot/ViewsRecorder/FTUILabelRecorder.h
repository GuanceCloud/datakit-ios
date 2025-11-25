//
//  FTUILabelRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes;
@protocol FTSRTextObfuscatingProtocol;

NS_ASSUME_NONNULL_BEGIN
@interface FTUILabelBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;

@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) BOOL fontScalingEnabled;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, assign) NSLineBreakMode lineBreakMode;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end
typedef FTUILabelBuilder* _Nullable (^FTBuilderOverride)(FTUILabelBuilder *builder);

@interface FTUILabelRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic,copy) FTTextObfuscator textObfuscator;
@property (nonatomic,copy) FTBuilderOverride builderOverride;
-(instancetype)initWithIdentifier:(NSString *)identifier builderOverride:(nullable FTBuilderOverride)builderOverride textObfuscator:(nullable FTTextObfuscator)textObfuscator;
@end

NS_ASSUME_NONNULL_END
