//
//  FTUIImageViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUIImageViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
#import "FTUIImageResource.h"
@implementation UIImage(FTRecord)
- (BOOL)isContextual API_AVAILABLE(ios(13.0)){
    return self.isSymbolImage || [self.description containsString:@"named("] || self.renderingMode == UIImageRenderingModeAlwaysTemplate;
}
- (BOOL)isTinted API_AVAILABLE(ios(13.0)){
    return self.isSymbolImage || self.isAlwaysTemplate;
}
- (BOOL)isBundled{
    return [self.description containsString:@"named("];
}
- (BOOL)isAlwaysTemplate{
    return self.renderingMode == UIImageRenderingModeAlwaysTemplate;
}
@end
@implementation UIImageView(FTRecord)
- (BOOL)isSystemControlBackground{
    return self.isButtonBackground || self.isBarBackground;
}
- (BOOL)isSystemShadow{
    return [NSStringFromClass(self.class) isEqualToString:@"_UICutoutShadowView"];
}
- (BOOL)isButtonBackground{
    if([self.superview isKindOfClass:UIButton.class]){
        UIButton *button = (UIButton *)self.superview;
        if(button.buttonType == UIButtonTypeCustom) {
            return [button backgroundImageForState:button.state] == self.image;
        }
    }
    return NO;
}
- (BOOL)isBarBackground{
    if(self.superview){
        return [NSStringFromClass(self.superview.class) isEqualToString:@"_UIBarBackground"];
    }
    return NO;
}
@end
@interface FTUIImageViewRecorder()

@end
@implementation FTUIImageViewRecorder
-(instancetype)init{
    return [self initWithIdentifier:[NSUUID UUID].UUIDString tintColorProvider:nil shouldRecordImagePredicateOverride:nil];
}
-(instancetype)initWithIdentifier:(NSString *)identifier tintColorProvider:(nullable FTTintColorProvider)tintColorProvider shouldRecordImagePredicateOverride:(nullable FTShouldRecordImagePredicate)shouldRecordImagePredicateOverride{
    self = [super init];
    if(self){
        _identifier = identifier;
        _semanticsOverride = ^FTSRNodeSemantics*(UIView *view, FTViewAttributes* attributes){
            UIImageView *imageView = (UIImageView *)view;
            return imageView.isSystemShadow?[[FTIgnoredElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore]:nil;
        };
        _tintColorProvider = tintColorProvider?tintColorProvider: ^UIColor*(UIImageView *imageView){
            if (@available(iOS 13.0, *)) {
                if(imageView.image){
                    return imageView.image.isTinted?imageView.tintColor:nil;
                }
            }
            return nil;
        };
        _shouldRecordImagePredicateOverride = shouldRecordImagePredicateOverride;
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UIImageView.class]){
        return nil;
    }
    UIImageView *imageView = (UIImageView *)view;
    FTSRNodeSemantics *semantics = self.semanticsOverride(imageView, attributes);
    if(semantics){
        return semantics;
    }
    if(!attributes.hasAnyAppearance && imageView.image == nil ){
        return [FTInvisibleElement constant];
    }
    CGRect contentFrame = CGRectZero;
    if(imageView.image){
        contentFrame = FTCGRectFitWithContentMode(attributes.frame, imageView.image.size, imageView.contentMode);
    }
    FTUIImageResource *imageResource = nil;
    BOOL shouldRecordImage = NO;
    if(self.shouldRecordImagePredicateOverride){
        shouldRecordImage = self.shouldRecordImagePredicateOverride(imageView);
    }else{
        shouldRecordImage = [self shouldRecordImagePredicate:imageView privacy:[attributes resolveImagePrivacyLevel:context.recorder]];
    }
    if (shouldRecordImage && imageView.image) {
        imageResource = [[FTUIImageResource alloc]initWithImage:imageView.image tintColor:self.tintColorProvider(imageView)];
    }
    NSArray *ids = [context.viewIDGenerator SRViewIDs:view size:2 nodeRecorder:self];
    FTUIImageViewBuilder *builder = [[FTUIImageViewBuilder alloc]init];
    builder.wireframeID = [ids[0] intValue];
    builder.imageWireframeID = [ids[1] intValue];
    builder.attributes = attributes;
    builder.contentFrame = contentFrame;
    builder.imageResource = imageResource;
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyRecord];
    element.nodes = @[builder];
    element.resources = builder.imageResource?@[builder.imageResource]:nil;
    return element;
}
- (BOOL)shouldRecordImagePredicate:(UIImageView *)imageView privacy:(FTImagePrivacyLevel)privacy{
    switch (privacy) {
        case FTImagePrivacyLevelMaskNonBundledOnly:
            if (@available(iOS 13.0, *)) {
                if(imageView.image){
                    return imageView.image.isContextual || imageView.isSystemControlBackground;
                }
            }
            return NO;
            break;
        case FTImagePrivacyLevelMaskAll:
            return NO;
        case FTImagePrivacyLevelMaskNone:
            return YES;
    }
}
@end
@implementation FTUIImageViewBuilder

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID attributes:self.attributes];
    if (!CGRectIsNull(self.contentFrame)){
        FTSRWireframe *contentWireframe;
        //        if(self.imageResource){
        //            FTSRImageWireframe *imageWireframe = [[FTSRImageWireframe alloc]initWithIdentifier:self.imageWireframeID frame:self.contentFrame];
        //            imageWireframe.resourceId = [self.imageResource calculateIdentifier];
        //            imageWireframe.clip = [[FTSRContentClip alloc]initWithFrame:self.contentFrame clip:self.attributes.clip];
        //            contentWireframe = imageWireframe;
        //        }else{
        FTSRPlaceholderWireframe *placeholderWireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.imageWireframeID frame:self.wireframeRect label:@"Content Image"];
        placeholderWireframe.clip = [[FTSRContentClip alloc]initWithFrame:self.wireframeRect clip:self.attributes.clip];
        contentWireframe = placeholderWireframe;
//                }
        return @[wireframe,contentWireframe];
    }
    
    return @[wireframe];
}
-(CGRect)wireframeRect{
    return self.attributes.frame;
}
@end
