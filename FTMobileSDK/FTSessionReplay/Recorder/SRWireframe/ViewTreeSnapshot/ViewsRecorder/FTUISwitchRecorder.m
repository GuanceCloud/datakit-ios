//
//  FTUISwitchRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUISwitchRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "UIView+FTSR.h"
#import "FTViewTreeRecordingContext.h"
@implementation FTUISwitchRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UISwitch.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UISwitch *switchView = (UISwitch *)view;
    
    CGRect realRect = CGRectMake(attributes.frame.origin.x, attributes.frame.origin.y, switchView.intrinsicContentSize.width, switchView.intrinsicContentSize.height);
    NSArray *ids = [context.viewIDGenerator SRViewIDs:switchView size:3 nodeRecorder:self];
    FTUISwitchBuilder *builder = [[FTUISwitchBuilder alloc]init];
    builder.wireframeRect = realRect;
    builder.attributes = attributes;
    builder.isDarkMode = switchView.usesDarkMode;
    builder.isOn = switchView.isOn;
    builder.isEnabled = switchView.isEnabled;
    builder.isMasked = context.recorder.privacy.shouldMaskInputElements;
    builder.thumbTintColor = switchView.thumbTintColor;
    builder.onTintColor = switchView.onTintColor;
    builder.offTintColor = switchView.tintColor;
    builder.backgroundWireframeID = [ids[0] intValue];
    builder.trackWireframeID = [ids[1] intValue];
    builder.thumbWireframeID = [ids[2] intValue];
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = @[builder];
    return element;
}
@end

@implementation FTUISwitchBuilder
- (NSArray<FTSRWireframe *> *)buildWireframes {
    if(self.isMasked){
        return [self createMaskWireframes];
    }else{
        return [self createNoMaskWireframes];
    }
}
- (NSArray<FTSRWireframe *> *)createMaskWireframes{
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]
                                     initWithIdentifier:self.trackWireframeID
                                     frame:self.attributes.frame
                                     clip:self.attributes.clip
                                     backgroundColor:[FTSystemColors tertiarySystemFillColorStr]
                                     cornerRadius:@(self.attributes.frame.size.height*0.5)
                                     opacity:self.isEnabled?@(self.attributes.alpha) : @(0.5)];

    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID attributes:self.attributes];
        return @[background,wireframe];
    }
    return @[wireframe];
}
- (NSArray<FTSRWireframe *> *)createNoMaskWireframes{
    CGFloat cornerRadius = self.wireframeRect.size.height * 0.5;
    NSString *trackColor = self.isOn? (self.onTintColor!=nil ? [FTSRUtils colorHexString:self.onTintColor.CGColor] : [FTSystemColors systemGreenColorStr]) : (self.offTintColor!=nil ? [FTSRUtils colorHexString:self.offTintColor.CGColor] : [FTSystemColors tertiarySystemFillColorStr]);
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]
                                     initWithIdentifier:self.trackWireframeID
                                     frame:self.wireframeRect
                                     clip:self.attributes.clip
                                     backgroundColor:trackColor
                                     cornerRadius:@(cornerRadius)
                                     opacity:self.isEnabled? @(self.attributes.alpha):@(0.5)];
    
    CGRect thumbContainer = CGRectInset(self.wireframeRect, 2, 2);
    CGRect thumbFrame = FTCGRectPutInside(CGRectMake(0, 0, thumbContainer.size.height, thumbContainer.size.height), thumbContainer, self.isOn?HorizontalAlignmentRight:HorizontalAlignmentLeft, VerticalAlignmentMiddle);
    NSString *thumbColor = self.thumbTintColor ? [FTSRUtils colorHexString:self.thumbTintColor.CGColor] : (self.isDarkMode && !self.isEnabled)? [FTSRUtils colorHexString:UIColor.grayColor.CGColor]:[FTSRUtils colorHexString:UIColor.whiteColor.CGColor];

    FTSRShapeWireframe *thumbWireframe = [[FTSRShapeWireframe alloc]
                                          initWithIdentifier:self.thumbWireframeID
                                          frame:thumbFrame
                                          clip:self.attributes.clip
                                          backgroundColor:thumbColor
                                          cornerRadius:@(cornerRadius)
                                          opacity:nil];
    thumbWireframe.border = [[FTSRShapeBorder alloc]initWithColor:[FTSystemColors secondarySystemFillColorStr] width:1];
    
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID attributes:self.attributes];
        return @[background,wireframe,thumbWireframe];
    }
    return @[wireframe,thumbWireframe];
}
@end
