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
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTUIViewRecorder.h"
#import "FTUIImageViewRecorder.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeRecorder.h"
#import "FTSRViewID.h"
typedef id<FTSRTextObfuscatingProtocol>(^FTTextFieldObfuscator)(FTViewTreeRecordingContext *context,FTViewAttributes *attributes,BOOL isSensitive,BOOL isPlaceholder);
@interface  FTUITextFieldRecorder()
@property (nonatomic, strong) FTUIViewRecorder *backgroundViewRecorder;
@property (nonatomic, strong) FTUIImageViewRecorder *iconsRecorder;
@property (nonatomic,copy) FTTextFieldObfuscator textObfuscator;
@property (nonatomic, strong) FTViewTreeRecorder *subtreeRecorder;
@end

@implementation FTUITextFieldRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _backgroundViewRecorder = [[FTUIViewRecorder alloc]initWithIdentifier:[NSUUID UUID].UUIDString];
        _iconsRecorder = [[FTUIImageViewRecorder alloc]initWithIdentifier:[NSUUID UUID].UUIDString tintColorProvider:nil shouldRecordImagePredicateOverride:nil];
        _subtreeRecorder = [[FTViewTreeRecorder alloc]init];
        _subtreeRecorder.nodeRecorders = @[_backgroundViewRecorder,_iconsRecorder];
    }
    return self;
}
-(FTTextFieldObfuscator)textObfuscator{
    return ^(FTViewTreeRecordingContext *context,FTViewAttributes *attributes,BOOL isSensitive,BOOL isPlaceholder){
        if (isPlaceholder) {
            return [FTSRTextObfuscatingFactory hintTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
        } else if (isSensitive) {
            return [FTSRTextObfuscatingFactory sensitiveTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
        } else {
            return [FTSRTextObfuscatingFactory inputAndOptionTextObfuscator:[attributes resolveTextAndInputPrivacyLevel:context.recorder]];
        }
    };
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UITextField.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return nil;
    }
    UITextField *textField = (UITextField *)view;
    NSMutableArray *node = [NSMutableArray new];
    NSMutableArray *resource = [NSMutableArray new];
    [self recordAppearance:textField textFieldAttributes:attributes context:context node:node resource:resource];
    FTUITextFieldBuilder *builder = [self recordText:textField attributes:attributes context:context];
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    if(builder){
        [node addObject:builder];
    }
    element.nodes = node;
    return element;
}
- (void)recordAppearance:(UITextField *)textField textFieldAttributes:(FTViewAttributes *)textFieldAttributes context:(FTViewTreeRecordingContext *)context node:(NSMutableArray *)node resource:(NSMutableArray *)resource{
    self.backgroundViewRecorder.semanticsOverride = ^FTSRNodeSemantics* _Nullable(UIView * _Nonnull view, FTViewAttributes * _Nonnull attributes) {
        BOOL hasSameSize = CGRectEqualToRect(textFieldAttributes.frame, attributes.frame);
        BOOL isBackground = hasSameSize && attributes.hasAnyAppearance;
        if(!isBackground) {
            FTIgnoredElement *element = [[FTIgnoredElement alloc]init];
            element.subtreeStrategy = NodeSubtreeStrategyRecord;
            return element;
        }
        return nil;
    };
    return [self.subtreeRecorder record:node resources:resource view:textField context:context];
}
- (FTUITextFieldBuilder *)recordText:(UITextField *)textField attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    NSString *text;
    BOOL isPlaceholder;
    if(textField.text && textField.text.length>0){
        text = textField.text;
        isPlaceholder = NO;
    }else if (textField.placeholder){
        text = textField.placeholder;
        isPlaceholder = YES;
    }else{
        return nil;
    }
    
    CGRect textFrame = CGRectInset(attributes.frame, 5, 5);
    FTUITextFieldBuilder *builder = [[FTUITextFieldBuilder alloc]init];
    builder.wireframeRect = textFrame;
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:textField nodeRecorder:self];
    builder.text = text;
    builder.textColor = textField.textColor;
    builder.textAlignment = textField.textAlignment;
    builder.isPlaceholderText = isPlaceholder;
    builder.font = textField.font;
    builder.fontScalingEnabled = textField.adjustsFontSizeToFitWidth;
    builder.textObfuscator = self.textObfuscator(context,attributes,[FTSRUtils isSensitiveText:textField],isPlaceholder);
    return builder;
}
@end
@implementation FTUITextFieldBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect];
    wireframe.text = [self.textObfuscator mask:self.text];
    wireframe.clip = [[FTSRContentClip alloc]initWithFrame:self.wireframeRect clip:self.attributes.clip];
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:self.attributes.backgroundColor.CGColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    FTAlignment *alignment = [[FTAlignment alloc]initWithTextAlignment:self.textAlignment vertical:@"center"];
    FTSRTextPosition *position = [[FTSRTextPosition alloc]init];
    position.alignment = alignment;
    position.padding = [[FTPadding alloc]initWithLeft:0 top:0 right:0 bottom:0];
    wireframe.textPosition = position;
    FTSRTextStyle *textStyle = [[FTSRTextStyle alloc]initWithSize:self.font.pointSize color:self.isPlaceholderText? [FTSystemColors placeholderTextColorStr]:[FTSRUtils colorHexString:self.textColor.CGColor] family:nil];
    wireframe.textStyle = textStyle;
    return @[wireframe];
}
@end
