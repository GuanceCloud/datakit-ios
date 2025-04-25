//
//  FTUITextFieldRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes;
@protocol FTSRTextObfuscatingProtocol;
NS_ASSUME_NONNULL_BEGIN
/// 绘制 textField
/// 不考虑 textFiled bolderStyle、光标、layer 层的自定义绘制
@interface FTUITextFieldBuilder:NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, assign) BOOL isPlaceholderText;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, assign) BOOL fontScalingEnabled;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end
@interface FTUITextFieldRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;

@end

NS_ASSUME_NONNULL_END
