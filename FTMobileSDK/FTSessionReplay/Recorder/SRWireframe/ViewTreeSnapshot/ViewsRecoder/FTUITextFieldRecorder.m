//
//  FTUITextFieldRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUITextFieldRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTUIViewRecorder.h"
#import "FTUIImageViewRecorder.h"
#import "FTViewTreeRecordingContext.h"
typedef id<FTSRTextObfuscatingProtocol>(^FTTextFieldObfuscator)(FTViewTreeRecordingContext *context,BOOL isSensitive,BOOL isPlaceholder);
@interface  FTUITextFieldRecorder()
@property (nonatomic, strong) FTUIViewRecorder *backgroundViewRecorder;
@property (nonatomic, strong) FTUIImageViewRecorder *iconsRecorder;
@property (nonatomic,copy) FTTextFieldObfuscator textObfuscator;

@end

@implementation FTUITextFieldRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _textObfuscator = ^(FTViewTreeRecordingContext *context,BOOL isSensitive,BOOL isPlaceholder){
            if (isPlaceholder) {
                return context.recorder.privacy.hintTextObfuscator;
            } else if (isSensitive) {
                return context.recorder.privacy.sensitiveTextObfuscator;
            } else {
                return context.recorder.privacy.inputAndOptionTextObfuscator;
            }
        };
    }
    return self;
}
-(id<FTSRNodeSemantics>)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if([view isKindOfClass:UITextField.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return nil;
    }
    
    return nil;
}
@end
@implementation FTUITextFieldBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect];
    wireframe.text = [self.textObfuscator mask:self.text];
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:self.attributes.backgroundColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    FTAlignment *alignment = [[FTAlignment alloc]initWithTextAlignment:self.textAlignment horizontal:@"center"];
    FTSRContentClip *padding = [[FTSRContentClip alloc]initWithLeft:0 top:0 right:0 bottom:0];
    FTSRTextPosition *position = [[FTSRTextPosition alloc]init];
    position.alignment = alignment;
    position.padding = padding;
    wireframe.textPosition = position;
    // TODO: 字体 family
    FTSRTextStyle *textStyle = [[FTSRTextStyle alloc]initWithSize:self.font.pointSize color:self.isPlaceholderText? [FTSystemColors placeholderTextColor]:[FTSRUtils colorHexString:self.textColor] family:@""];
    wireframe.textStyle = textStyle;
    return @[wireframe];
}
@end
