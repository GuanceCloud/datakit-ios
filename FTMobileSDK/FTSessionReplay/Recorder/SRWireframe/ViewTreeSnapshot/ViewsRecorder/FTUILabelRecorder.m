//
//  FTUILabelRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUILabelRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"

@interface FTUILabelRecorder()
@end
@implementation FTUILabelRecorder
-(instancetype)init{
    return [self initWithIdentifier:[NSUUID UUID].UUIDString builderOverride:nil textObfuscator:nil];
}
-(instancetype)initWithIdentifier:(NSString *)identifier builderOverride:(FTBuilderOverride)builderOverride textObfuscator:(FTTextObfuscator)textObfuscator{
    self = [super init];
    if(self){
        _identifier = identifier;
        _builderOverride = builderOverride?builderOverride:^(FTUILabelBuilder *builder){
            return builder;
        };
        _textObfuscator = textObfuscator?textObfuscator:^id<FTSRTextObfuscatingProtocol> _Nullable(FTViewTreeRecordingContext * _Nonnull context) {
            return [context.recorder.privacy staticTextObfuscator];
        };
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:[UILabel class]]){
        return nil;
    }
    UILabel *label = (UILabel *)view;
    BOOL hasVisibleText = attributes.isVisible && label.text.length>0;
    if(!hasVisibleText && !attributes.hasAnyAppearance){
        return [FTInvisibleElement constant];
    }
    FTUILabelBuilder *builder = [[FTUILabelBuilder alloc]init];
    builder.text = label.text?:@"";
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:label nodeRecorder:self];
    builder.adjustsFontSizeToFitWidth = label.adjustsFontSizeToFitWidth;
    builder.font = label.font;
    builder.textColor = label.textColor;
    builder.textAlignment = label.textAlignment;
    builder.textObfuscator = self.textObfuscator(context);
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[self.builderOverride(builder)];
    return element;
}
@end

@implementation FTUILabelBuilder

-(CGRect)wireframeRect{    
    return self.attributes.frame;
}
-(NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRTextWireframe *wireframe = [[FTSRTextWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect];

    wireframe.text = [self.textObfuscator mask:self.text];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:self.attributes.layerBorderColor] width:self.attributes.layerBorderWidth];
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:self.attributes.backgroundColor.CGColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.textStyle = [[FTSRTextStyle alloc]initWithSize:self.font.pointSize color:[FTSRUtils colorHexString:self.textColor.CGColor] family:nil];
    FTSRTextPosition *textPosition = [[FTSRTextPosition alloc]init];
    textPosition.alignment = [[FTAlignment alloc]initWithTextAlignment:self.textAlignment vertical:@"center"];
    textPosition.padding = [[FTSRContentClip alloc]initWithLeft:0 top:0 right:0 bottom:0];
    wireframe.textPosition = textPosition;
    return @[wireframe];
}
@end
