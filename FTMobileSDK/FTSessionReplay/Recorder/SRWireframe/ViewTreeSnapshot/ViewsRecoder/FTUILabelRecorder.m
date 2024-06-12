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
typedef id<FTSRTextObfuscatingProtocol>(^FTTextObfuscator)(FTRecorderContext *context);
@interface FTUILabelRecorder()
@property (nonatomic,copy) FTTextObfuscator textObfuscator;
@end
@implementation FTUILabelRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _textObfuscator = ^(FTRecorderContext *context){
            return [context.recorder.privacy staticTextObfuscator];
        };
    }
    return self;
}
-(NSArray<id<FTSRWireframesBuilder>> *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTRecorderContext *)context{
    if(![view isKindOfClass:[UILabel class]]){
        return nil;
    }
    UILabel *label = (UILabel *)view;
    BOOL hasVisibleText = attributes.isVisible && label.text.length>0;
    if(!hasVisibleText && !attributes.hasAnyAppearance){
        return nil;
    }
    FTUILabelBuilder *builder = [[FTUILabelBuilder alloc]init];
    builder.text = label.text;
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:label];
    builder.adjustsFontSizeToFitWidth = label.adjustsFontSizeToFitWidth;
    builder.font = label.font;
    builder.textColor = label.textColor.CGColor;
    builder.textAlignment = label.textAlignment;
    builder.textObfuscator = self.textObfuscator(context);
    return @[builder];
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
    wireframe.textStyle = [[FTSRTextStyle alloc]initWithSize:self.font.pointSize color:[FTSRUtils colorHexString:self.textColor] family:self.font.familyName];
    FTSRTextPosition *textPosition = [[FTSRTextPosition alloc]init];
    textPosition.alignment = [[FTAlignment alloc]initWithTextAlignment:self.textAlignment horizontal:@"center"];
    wireframe.textPosition = textPosition;
    return @[wireframe];
}
@end
