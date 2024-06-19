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
#import "FTSRWireframesBuilder.h"
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
    builder.thumbTintColor = switchView.thumbTintColor.CGColor;
    builder.onTintColor = switchView.onTintColor.CGColor;
    builder.offTintColor = switchView.tintColor.CGColor;
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
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.trackWireframeID frame:self.attributes.frame];
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSystemColors tertiarySystemFillColor] cornerRadius:@(self.attributes.frame.size.width/2) opacity:self.isEnabled?@(self.attributes.alpha) : @(0.5)];
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.attributes.frame attributes:self.attributes];
        return @[background,wireframe];
    }
    return @[wireframe];
}
- (NSArray<FTSRWireframe *> *)createNoMaskWireframes{
    CGFloat cornerRadius = self.wireframeRect.size.height / 2;
    NSString *trackColor = self.isOn? (self.onTintColor!=nil ? [FTSRUtils colorHexString:self.onTintColor] : [FTSystemColors systemGreenColor]) : (self.offTintColor!=nil ? [FTSRUtils colorHexString:self.offTintColor] : [FTSystemColors tertiarySystemFillColor]);
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.trackWireframeID frame:self.wireframeRect];
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:trackColor cornerRadius:@(cornerRadius) opacity:self.isEnabled? @(self.attributes.alpha):@(0.5)];
    
    CGRect contentSize = FTCGRectFitWithContentMode(self.wireframeRect, CGSizeMake(self.wireframeRect.size.width-4, self.wireframeRect.size.width-4), UIViewContentModeCenter);
    CGRect thumbSize = FTCGRectFitWithContentMode(contentSize, CGSizeMake(contentSize.size.height, contentSize.size.height),self.isOn? UIViewContentModeRight:UIViewContentModeLeft);
    FTSRShapeWireframe *thumbWireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.thumbWireframeID frame:thumbSize];
    NSString *thumbColor = self.thumbTintColor ? [FTSRUtils colorHexString:self.thumbTintColor] : (self.isDarkMode && !self.isEnabled)? [FTSRUtils colorHexString:UIColor.grayColor.CGColor]:[FTSRUtils colorHexString:UIColor.whiteColor.CGColor];
    thumbWireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:thumbColor cornerRadius:@(cornerRadius-1) opacity:@(1)];
    
    if(self.attributes.hasAnyAppearance){
        FTSRShapeWireframe *background = [[FTSRShapeWireframe alloc]initWithIdentifier:self.backgroundWireframeID frame:self.attributes.frame attributes:self.attributes];
        return @[background,wireframe,thumbWireframe];
    }
    return @[wireframe,thumbWireframe];
}
@end
