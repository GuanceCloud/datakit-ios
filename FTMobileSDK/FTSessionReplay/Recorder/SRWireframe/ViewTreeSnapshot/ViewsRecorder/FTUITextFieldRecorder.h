//
//  FTUITextFieldRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRWireframesBuilder.h"

@class FTViewAttributes;
@protocol FTSRTextObfuscatingProtocol;
NS_ASSUME_NONNULL_BEGIN
/// Draw textField
/// Does not consider textField bolderStyle, cursor, layer custom drawing
@interface FTUITextFieldBuilder:NSObject<FTSRWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) int wireframeID;
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
