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
@interface FTUIImageViewRecorder()
@property (nonatomic,copy,readwrite) NSString *identifier;

@end
@implementation FTUIImageViewRecorder
-(NSArray<id<FTSRWireframesBuilder>> *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTRecorderContext *)context{
    if(![view isKindOfClass:UIImageView.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return nil;
    }
    UIImageView *imageView = (UIImageView *)view;
    FTUIImageViewBuilder *builder = [[FTUIImageViewBuilder alloc]init];
    builder.attributes = attributes;
    builder.image = imageView.image;
    builder.clipsToBounds = imageView.clipsToBounds;
    builder.tintColor = imageView.tintColor;
    return @[builder];
}
@end
@implementation FTUIImageViewBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.attributes.frame attributes:self.attributes];
    NSString *imageBase64;
    if(self.shouldRecordImage){
        if(self.imageDataProvider && [self.imageDataProvider respondsToSelector:@selector(imageContentBase64String:tintColor:)]){
            [self.imageDataProvider imageContentBase64String:self.image tintColor:self.tintColor];
        }
    }
    if (!CGRectIsNull(self.contentFrame)){
        CGRect relativeIntersectedRect = CGRectIntersection(self.attributes.frame, self.contentFrame);
        FTSRWireframe *contentWireframe;
        if(imageBase64){
            FTSRImageWireframe *imageWireframe = [[FTSRImageWireframe alloc]initWithIdentifier:self.imageWireframeID frame:self.contentFrame];
            imageWireframe.base64 = imageBase64;
            imageWireframe.mimeType = @"png";
            imageWireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:self.attributes.backgroundColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
            if(self.clipsToBounds){
                CGFloat top = MAX(relativeIntersectedRect.origin.y - self.contentFrame.origin.y, 0);
                CGFloat left = MAX(relativeIntersectedRect.origin.x - self.contentFrame.origin.x, 0);
                CGFloat bottom = MAX(self.contentFrame.size.height - (relativeIntersectedRect.size.height + top), 0);
                CGFloat right = MAX(self.contentFrame.size.width - (relativeIntersectedRect.size.width + left), 0);
                FTSRContentClip *clip = [[FTSRContentClip alloc]initWithLeft:left top:top right:right bottom:bottom];
                imageWireframe.clip = clip;
            }
            contentWireframe = imageWireframe;
        }else{
            FTSRPlaceholderWireframe *placeholderWireframe = [[FTSRPlaceholderWireframe alloc]initWithIdentifier:self.imageWireframeID frame:self.contentFrame label:@"Content Image"];
            contentWireframe = placeholderWireframe;
        }
        return @[wireframe,contentWireframe];
    }
    
    return @[wireframe];
}
@end
