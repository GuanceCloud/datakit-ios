//
//  FTUITabBarRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUITabBarRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeRecorder.h"
#import "FTUIImageViewRecorder.h"
#import "FTUILabelRecorder.h"
#import "FTUIViewRecorder.h"
#import <CoreGraphics/CGImage.h>
#import "FTSystemColors.h"
@implementation UIImage(FTTabBarRecorder)
- (NSString *)uniqueDescription{
    if(self.CGImage){
        CGImageRef cgImage = self.CGImage;
        return [NSString stringWithFormat:@"%zux%zux-%zux%zu-%zu-%u",CGImageGetWidth(cgImage),CGImageGetHeight(cgImage),CGImageGetBitsPerComponent(cgImage),CGImageGetBitsPerPixel(cgImage),CGImageGetBytesPerRow(cgImage),CGImageGetBitmapInfo(cgImage)];
    }
    return nil;
}
@end
@interface FTUITabBarRecorder()
@property (nonatomic, strong) FTViewTreeRecorder *subtreeRecorder;
@end
@implementation FTUITabBarRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:[UITabBar class]]){
        return nil;
    }
    // TODO: 确认是否在 TabBar hidden 的时候隐藏
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UITabBar *tabBar = (UITabBar *)view;
    FTUITabBarBuilder *builder = [[FTUITabBarBuilder alloc]init];
    builder.color = [self inferTabBarColor:tabBar];
    builder.wireframeID = [context.viewIDGenerator SRViewID:tabBar nodeRecorder:self];
    builder.wireframeRect = [self inferBarFrame:tabBar context:context];
    builder.attributes = attributes;
    NSMutableArray *records = [NSMutableArray arrayWithArray:@[builder]];
    NSMutableArray *resources = [NSMutableArray array];
    [self recordSubtree:tabBar records:records resources:resources context:context];
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = records;
    element.resources = resources;
    return element;
}
- (void)recordSubtree:(UITabBar *)tabBar records:(NSMutableArray *)records resources:(NSMutableArray *)resources context:(FTViewTreeRecordingContext *)context{
    FTViewTreeRecorder *viewTreeRecorder = [[FTViewTreeRecorder alloc]init];
    FTUIImageViewRecorder *imageViewRecorder = [[FTUIImageViewRecorder alloc]initWithIdentifier:self.identifier tintColorProvider:^UIColor * _Nullable(UIImageView * _Nonnull imageView) {
        if(imageView.image){
            UITabBarItem *currentItemInSelectedState = nil;
            NSString *uniqueDescription = tabBar.items.firstObject.selectedImage.uniqueDescription;
            if(uniqueDescription){
                currentItemInSelectedState = [uniqueDescription isEqualToString:imageView.image.uniqueDescription]?tabBar.items.firstObject:nil;
            }
            if(currentItemInSelectedState == nil || tabBar.selectedItem != currentItemInSelectedState){
                return tabBar.unselectedItemTintColor?tabBar.unselectedItemTintColor:[[UIColor systemGrayColor] colorWithAlphaComponent:0.5];
            }
            return tabBar.tintColor?: [UIColor systemBlueColor];
        }
        return nil;
    } shouldRecordImagePredicate:nil];
    viewTreeRecorder.nodeRecorders = @[
        imageViewRecorder,
        [[FTUILabelRecorder alloc] initWithIdentifier:self.identifier builderOverride:nil textObfuscator:nil],
        [[FTUIViewRecorder alloc] initWithIdentifier:self.identifier],
    ];
    
    [viewTreeRecorder record:records resources:resources view:tabBar context:context];
}
- (UIColor *)inferTabBarColor:(UITabBar *)bar{
    if(bar.backgroundColor){
        return bar.backgroundColor;
    }
    if (@available(iOS 13.0, *)) {
        switch ([UITraitCollection currentTraitCollection].userInterfaceStyle) {
            case UIUserInterfaceStyleLight:
                return [UIColor whiteColor];
            case UIUserInterfaceStyleDark:
                return [UIColor blackColor];
            default:
                return [UIColor whiteColor];
        }
    }
    return UIColor.whiteColor;
}

- (CGRect)inferBarFrame:(UITabBar *)bar context:(FTViewTreeRecordingContext *)context{
    CGRect newRect = bar.frame;
    for (UIView *view in bar.subviews) {
        CGRect subViewRect = [view convertRect:view.bounds toCoordinateSpace:context.coordinateSpace];
        newRect = CGRectUnion(newRect, subViewRect);
    }
    return newRect;
}
@end

@implementation FTUITabBarBuilder
- (NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect clip:self.attributes.clip backgroundColor:[FTSRUtils colorHexString:self.color.CGColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:[FTSRUtils colorHexString:[[UIColor lightGrayColor] colorWithAlphaComponent:0.5].CGColor] width:0.5];
    return @[wireframe];
}
@end
