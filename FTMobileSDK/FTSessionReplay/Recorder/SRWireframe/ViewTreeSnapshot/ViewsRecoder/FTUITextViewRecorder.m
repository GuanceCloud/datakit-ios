//
//  FTUITextViewRecoder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUITextViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
typedef id<FTSRTextObfuscatingProtocol>(^FTTextViewObfuscator)(FTRecorderContext *context,BOOL isSensitive,BOOL isEditable);

@interface FTUITextViewRecorder()
@property (nonatomic,copy) FTTextViewObfuscator textObfuscator;
@end
@implementation FTUITextViewRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _textObfuscator = ^(FTRecorderContext *context,BOOL isSensitive,BOOL isEditable){
            if (isSensitive) {
                return context.recorder.privacy.sensitiveTextObfuscator;
            }

            if (isEditable) {
                return context.recorder.privacy.inputAndOptionTextObfuscator;
            } else {
                return context.recorder.privacy.staticTextObfuscator;
            }
        };
    }
    return self;
}
-(NSArray<id<FTSRWireframesBuilder>> *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTRecorderContext *)context{
    if(![view isKindOfClass:[UITextView class]]){
        return nil;
    }
    if(!attributes.isVisible){
        return nil;
    }
    UITextView *textView = (UITextView *)view;
    FTUITextViewBuilder *builder = [[FTUITextViewBuilder alloc]init];
    builder.attributes = attributes;
    builder.text = textView.text;
    builder.textAlignment = textView.textAlignment;
    builder.textColor = textView.textColor.CGColor;
    builder.font = textView.font;
    builder.contentRect = CGRectMake(textView.contentOffset.x, textView.contentOffset.y, textView.contentSize.width, textView.contentSize.height);
    // TODO：
    //builder.textObfuscator =
    return @[builder];
}

@end

@implementation FTUITextViewBuilder


- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect];
    wireframe.text = [self.textObfuscator mask:self.text];
    CGFloat top = self.contentRect.origin.y;
    CGFloat left = self.contentRect.origin.x;
    CGFloat right = MAX(self.contentRect.size.width - self.wireframeRect.size.width - left, 0);
    CGFloat bottom = MIN(self.contentRect.size.height - self.wireframeRect.size.height - top, 0);
    FTSRContentClip *clip = [[FTSRContentClip alloc]initWithLeft:left top:top right:right bottom:bottom];
    wireframe.clip = clip;
    FTSRShapeStyle *shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:self.attributes.backgroundColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.shapeStyle = shapeStyle;
    // TODO: family
    FTAlignment *alignment = [[FTAlignment alloc]initWithTextAlignment:NSTextAlignmentLeft horizontal:@"top"];
    wireframe.textStyle = [[FTSRTextStyle alloc]initWithSize:self.font.pointSize color:[FTSRUtils colorHexString:self.textColor] family:@""];
    FTSRTextPosition *position = [[FTSRTextPosition alloc]init];
    position.alignment = alignment;
    wireframe.textPosition = position;
    return @[wireframe];
}

- (CGRect)wireframeRect{
    return self.attributes.frame;
}
@end
