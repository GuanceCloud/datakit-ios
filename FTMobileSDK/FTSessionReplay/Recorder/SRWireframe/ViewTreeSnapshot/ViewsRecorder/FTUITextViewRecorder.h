//
//  FTUITextViewRecoder.h
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
typedef id<FTSRTextObfuscatingProtocol>_Nullable(^FTTextViewObfuscator)(FTViewTreeRecordingContext *context,BOOL isSensitive,BOOL isEditable);
@interface FTUITextViewBuilder:NSObject<FTSRWireframesBuilder>
@property (nonatomic, assign) int wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;

@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nullable) CGColorRef textColor;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, assign) CGRect contentRect;
@property (nonatomic, strong) id<FTSRTextObfuscatingProtocol> textObfuscator;
@end
@interface FTUITextViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic,copy) FTTextViewObfuscator textObfuscator;

@end

NS_ASSUME_NONNULL_END
