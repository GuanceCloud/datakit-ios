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
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
#import "FTUIImageResource.h"

@interface FTUIImageViewRecorder()

@end
@implementation FTUIImageViewRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _semanticsOverride = ^FTSRNodeSemantics*(UIView *view, FTViewAttributes* attributes){
            if([NSStringFromClass(view.class) isEqualToString:@"_UICutoutShadowView"]){
                return [[FTIgnoredElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
            }
            return nil;
        };
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
    CGRect contentFrame = CGRectNull;
    BOOL shouldRecordImage = NO;
    UIColor *tintColor;
    if(imageView.image){
        contentFrame = FTCGRectFitWithContentMode(attributes.frame, imageView.image.size, imageView.contentMode);
        if (@available(iOS 13.0, *)) {
            shouldRecordImage = [self imageIsContextual:imageView.image] || [self imageViewIsSystemControlBackground:imageView];
            BOOL isTinted = imageView.image.isSymbolImage || imageView.image.renderingMode == UIImageRenderingModeAlwaysTemplate;
            tintColor = isTinted?imageView.tintColor:nil;
        }

    }
    FTUIImageResource *imageResource = [[FTUIImageResource alloc]initWithImage:imageView.image tintColor:tintColor];
    NSArray *ids = [context.viewIDGenerator SRViewIDs:view size:2 nodeRecorder:self];
    FTUIImageViewBuilder *builder = [[FTUIImageViewBuilder alloc]init];
    builder.wireframeID = [ids[0] intValue];
    builder.imageWireframeID = [ids[1] intValue];
    builder.attributes = attributes;
    builder.contentFrame = contentFrame;
    builder.clipsToBounds = imageView.clipsToBounds;
    builder.tintColor = imageView.tintColor;
    builder.shouldRecordImage = shouldRecordImage;
    builder.imageResource = shouldRecordImage?imageResource:nil;
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyRecord];
    element.nodes = @[builder];
    element.resources = builder.imageResource?@[builder.imageResource]:nil;
    return element;
}
- (BOOL)imageIsContextual:(UIImage *)image{
    if (@available(iOS 13.0, *)) {
        return image.isSymbolImage || [image.description containsString:@"named("] || image.renderingMode == UIImageRenderingModeAlwaysTemplate;
    }
    return NO;
}
- (BOOL)imageViewIsSystemControlBackground:(UIImageView *)imageView{
    if([imageView.superview isKindOfClass:UIButton.class]){
        UIButton *button = (UIButton *)imageView.superview;
        if(button.buttonType == UIButtonTypeCustom) {
            return [button backgroundImageForState:button.state] == imageView.image;
        }
    }
    return NO;
}
@end
@implementation FTUIImageViewBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.attributes.frame attributes:self.attributes];
    if (!CGRectIsNull(self.contentFrame)){
        FTSRWireframe *contentWireframe;
        if(self.imageResource){
            FTSRImageWireframe *imageWireframe = [[FTSRImageWireframe alloc]initWithIdentifier:self.imageWireframeID frame:self.contentFrame];
            imageWireframe.resourceId = [self.imageResource calculateIdentifier];
            imageWireframe.clip = self.clipsToBounds?[self clip]:nil;
            contentWireframe = imageWireframe;
        }else{
            FTSRPlaceholderWireframe *placeholderWireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.imageWireframeID frame:self.clipsToBounds?[self relativeIntersectedRect]:CGRectNull label:@"Content Image"];
            contentWireframe = placeholderWireframe;
        }
        return @[wireframe,contentWireframe];
    }
    
    return @[wireframe];
}
- (CGRect)relativeIntersectedRect{
    if(!CGRectIsNull(self.contentFrame)){
        return CGRectIntersection(self.attributes.frame, self.contentFrame);
    }else{
        return CGRectZero;
    }
}
- (FTSRContentClip *)clip{
    if(CGRectIsNull(self.contentFrame)){
        return nil;
    }
    CGRect relativeIntersectedRect = [self relativeIntersectedRect];
    CGFloat top = MAX(relativeIntersectedRect.origin.y - self.contentFrame.origin.y, 0);
    CGFloat left = MAX(relativeIntersectedRect.origin.x - self.contentFrame.origin.x, 0);
    CGFloat bottom = MAX(self.contentFrame.size.height - (relativeIntersectedRect.size.height + top), 0);
    CGFloat right = MAX(self.contentFrame.size.width - (relativeIntersectedRect.size.width + left), 0);
    return [[FTSRContentClip alloc]initWithLeft:left top:top right:right bottom:bottom];
}
@end
