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
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTViewTreeRecordingContext.h"
#import "FTSRUtils.h"

@interface FTUITextViewRecorder()
@end
@implementation FTUITextViewRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _textObfuscator = ^(FTViewTreeRecordingContext *context,FTViewAttributes *attributes,BOOL isSensitive,BOOL isEditable){
            if (isSensitive) {
                return [FTSRTextObfuscatingFactory sensitiveTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
            }

            if (isEditable) {
                return [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
            } else {
                return [FTSRTextObfuscatingFactory staticTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
            }
        };
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:[UITextView class]]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UITextView *textView = (UITextView *)view;
    FTUITextViewBuilder *builder = [[FTUITextViewBuilder alloc]init];
    builder.attributes = attributes;
    builder.text = textView.text;
    builder.textAlignment = textView.textAlignment;
    builder.textColor = textView.textColor;
    builder.font = textView.font;
    builder.contentRect = CGRectMake(textView.contentOffset.x, textView.contentOffset.y, textView.contentSize.width, textView.contentSize.height);
    builder.textObfuscator = self.textObfuscator(context,attributes,[FTSRUtils isSensitiveText:textView],textView.isEditable);
    builder.contentRect = CGRectMake(textView.contentOffset.x, textView.contentOffset.y, textView.contentSize.width, textView.contentSize.height);
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}

@end

@implementation FTUITextViewBuilder


- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder{
    CGRect frame = [self relativeIntersectedRect];
    FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc]initWithIdentifier:self.wireframeID frame:frame];
    wireframe.text = [self.textObfuscator mask:self.text];
    wireframe.clip = [[FTSRContentClip alloc]initWithFrame:frame clip:self.attributes.clip];
    FTSRShapeStyle *shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:self.attributes.backgroundColor.CGColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.shapeStyle = shapeStyle;
    FTAlignment *alignment = [[FTAlignment alloc]initWithTextAlignment:NSTextAlignmentLeft vertical:@"top"];
    wireframe.textStyle = [[FTSRTextStyle alloc]initWithSize:self.font.pointSize color:[FTSRUtils colorHexString:self.textColor.CGColor] family:nil];
    FTSRTextPosition *position = [[FTSRTextPosition alloc]init];
    position.alignment = alignment;
    position.padding = [[FTPadding alloc]initWithLeft:0 top:0 right:0 bottom:0];
    wireframe.textPosition = position;
    return @[wireframe];
}
- (CGRect)relativeIntersectedRect{
    CGFloat padding = 8;
    return CGRectMake(self.wireframeRect.origin.x-self.contentRect.origin.x+padding, self.wireframeRect.origin.y-self.contentRect.origin.y+padding, MAX(self.contentRect.size.width, self.wireframeRect.size.width)-padding, MAX(self.contentRect.size.height, self.wireframeRect.size.height)-padding);
}
- (CGRect)wireframeRect{
    return self.attributes.frame;
}
@end
