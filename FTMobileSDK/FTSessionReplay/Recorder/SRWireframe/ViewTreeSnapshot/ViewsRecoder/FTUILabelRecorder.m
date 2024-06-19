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
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"

@interface FTUILabelRecorder()
@end
@implementation FTUILabelRecorder
-(instancetype)init{
    return [self initWithBuilderOverride:^(FTUILabelBuilder *builder){
        return builder;
    } textObfuscator:^id<FTSRTextObfuscatingProtocol> _Nullable(FTViewTreeRecordingContext *context) {
        return [context.recorder.privacy staticTextObfuscator];
    }];
}
-(instancetype)initWithBuilderOverride:(FTBuilderOverride)builderOverride textObfuscator:(FTTextObfuscator)textObfuscator{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _builderOverride = builderOverride;
        _textObfuscator = textObfuscator;
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
    builder.text = label.text;
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:label nodeRecorder:self];
    builder.adjustsFontSizeToFitWidth = label.adjustsFontSizeToFitWidth;
    builder.font = label.font;
    builder.textColor = label.textColor.CGColor;
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
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:self.attributes.backgroundColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    // TODO: 字体 family
    wireframe.textStyle = [[FTSRTextStyle alloc]initWithSize:self.font.pointSize color:[FTSRUtils colorHexString:self.textColor] family:nil];
    FTSRTextPosition *textPosition = [[FTSRTextPosition alloc]init];
    textPosition.alignment = [[FTAlignment alloc]initWithTextAlignment:self.textAlignment horizontal:@"center"];
    wireframe.textPosition = textPosition;
    return @[wireframe];
}
@end
