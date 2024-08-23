//
//  FTUIActivityIndicatorRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTUIActivityIndicatorRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTViewTreeRecordingContext.h"
#import "FTSRUtils.h"
#import "FTViewTreeRecorder.h"
#import "FTUIImageViewRecorder.h"
@interface FTUIActivityIndicatorRecorder()
@property (nonatomic, strong) FTViewTreeRecorder *subtreeRecorder;
@end
@implementation FTUIActivityIndicatorRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:[UIActivityIndicatorView class]]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UIActivityIndicatorView *activityIndicator = (UIActivityIndicatorView*)view;
    if(activityIndicator.isAnimating || !activityIndicator.hidesWhenStopped){
        FTUIActivityIndicatorBuilder *builder = [[FTUIActivityIndicatorBuilder alloc]init];
        builder.attributes = attributes;
        builder.wireframeID = [context.viewIDGenerator SRViewID:activityIndicator nodeRecorder:self];
        builder.backgroundColor = activityIndicator.backgroundColor.CGColor;
        NSMutableArray *records = [NSMutableArray arrayWithArray:@[builder]];
        NSMutableArray *resources = [NSMutableArray array];
        [self recordSubtree:activityIndicator records:records resources:resources context:context];
        FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
        element.nodes = records;
        element.resources = resources;
        return element;
    }else{
        return [FTInvisibleElement constant];
    }
}
- (void)recordSubtree:(UIActivityIndicatorView *)activityIndicator records:(NSMutableArray *)records resources:(NSMutableArray *)resources context:(FTViewTreeRecordingContext *)context{
    if(!_subtreeRecorder){
        FTViewTreeRecorder *viewTreeRecorder = [[FTViewTreeRecorder alloc]init];
        FTUIImageViewRecorder *imageViewRecorder = [[FTUIImageViewRecorder alloc]initWithIdentifier:self.identifier tintColorProvider:nil shouldRecordImagePredicate: ^BOOL(UIImageView * _Nonnull imageView) {
            return imageView.image != nil;
        }];
        viewTreeRecorder.nodeRecorders = @[imageViewRecorder];
        self.subtreeRecorder = viewTreeRecorder;
    }
    [self.subtreeRecorder record:records resources:resources view:activityIndicator context:context];
}
@end

@implementation FTUIActivityIndicatorBuilder

-(NSArray<FTSRWireframe *> *)buildWireframes{
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect backgroundColor:[FTSRUtils colorHexString:self.backgroundColor] cornerRadius:@(self.attributes.layerCornerRadius) opacity:@(self.attributes.alpha)];
    return @[wireframe];
}
-(CGRect)wireframeRect{
    return self.attributes.frame;
}
@end


