//
//  FTUIPickerViewRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUIPickerViewRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTImageDataUtils.h"
#import "FTViewTreeRecordingContext.h"
#import "FTViewTreeRecorder.h"
#import "FTUIViewRecorder.h"
#import "FTUILabelRecorder.h"
#import "FTViewTreeRecordingContext.h"
@interface FTUIPickerViewRecorder()
@property (nonatomic, strong) FTViewTreeRecorder *selectionRecorder;
@property (nonatomic, strong) FTViewTreeRecorder *labelsRecorder;
@end
@implementation FTUIPickerViewRecorder
-(instancetype)init{
    return [self initWithTextObfuscator: ^(FTViewTreeRecordingContext *context){
        return context.recorder.privacy.inputAndOptionTextObfuscator;
    }];
}
-(instancetype)initWithTextObfuscator:(FTTextObfuscator)textObfuscator{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
        _textObfuscator = textObfuscator;
        FTViewTreeRecorder *selectionRecorder = [[FTViewTreeRecorder alloc]init];
        selectionRecorder.nodeRecorders = @[[[FTUIViewRecorder alloc]initWithSemanticsOverride:^FTSRNodeSemantics* _Nullable(UIView *view, FTViewAttributes *attributes) {
            if (@available(iOS 13, *)) {
                if(!attributes.isVisible || attributes.alpha<1 || !CATransform3DIsIdentity(view.transform3D) ){
                    FTIgnoredElement *element = [[FTIgnoredElement alloc]init];
                    element.subtreeStrategy = NodeSubtreeStrategyIgnore;
                    return element;
                }
            }
            FTIgnoredElement *element = [[FTIgnoredElement alloc]init];
            element.subtreeStrategy = NodeSubtreeStrategyRecord;
            return element;
        }]];
        _selectionRecorder = selectionRecorder;
        _labelsRecorder = [[FTViewTreeRecorder alloc]init];
        _labelsRecorder.nodeRecorders = @[
            [[FTUIViewRecorder alloc]init],
            [[FTUILabelRecorder alloc]initWithBuilderOverride:^FTUILabelBuilder * _Nullable(FTUILabelBuilder *builder) {
                builder.textAlignment = NSTextAlignmentCenter;
                builder.adjustsFontSizeToFitWidth = YES;
                return builder;
            } textObfuscator:textObfuscator],];
    }
    return self;
}

-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UIPickerView.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    NSMutableArray *nodes = [NSMutableArray new];
    NSMutableArray *resources = [NSMutableArray new];
    
    [self.selectionRecorder record:nodes resources:resources view:view context:context];
    [self.labelsRecorder record:nodes resources:resources view:view context:context];
    
    if(!attributes.hasAnyAppearance){
        FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
        element.nodes = nodes;
        element.resources = resources;
        return element;
    }
    FTUIPickerViewBuilder *builder = [[FTUIPickerViewBuilder alloc]init];
    builder.wireframeRect = attributes.frame;
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    
    [nodes insertObject:builder atIndex:0];
    
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = nodes;
    element.resources = resources;
    return element;
}
@end

@implementation FTUIPickerViewBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect attributes:self.attributes];
    return @[wireframe];
}

@end


