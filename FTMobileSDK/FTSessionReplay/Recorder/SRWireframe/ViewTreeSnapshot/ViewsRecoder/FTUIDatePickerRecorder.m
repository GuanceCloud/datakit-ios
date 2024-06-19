//
//  FTUIDatePickerRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUIDatePickerRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
#import "FTUIViewRecorder.h"
#import "FTUILabelRecorder.h"
#import "FTViewTreeRecorder.h"
#import "FTUIImageViewRecorder.h"
#import "FTUISegmentRecorder.h"
#import "FTViewTreeRecordingContext.h"
#import "FTUIPickerViewRecorder.h"
@interface FTUIDatePickerRecorder()

@end
@implementation FTUIDatePickerRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(FTSRNodeSemantics *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context{
    if(![view isKindOfClass:UIDatePicker.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return [FTInvisibleElement constant];
    }
    UIDatePicker *datePicker = (UIDatePicker *)view;
    NSMutableArray *nodes = [NSMutableArray new];
    NSMutableArray *resources = [NSMutableArray new];
    if (@available(iOS 13.4, *)) {
        switch (datePicker.preferredDatePickerStyle) {
            case UIDatePickerStyleCompact:
            {
                FTCompactStyleDatePickerRecorder *recorder =   [[FTCompactStyleDatePickerRecorder alloc] init];
                [recorder recorder:datePicker attributes:attributes context:context nodes:nodes resources:resources];
            }
                break;
            case UIDatePickerStyleInline:{
                FTInlineStyleDatePickerRecorder *recorder =   [[FTInlineStyleDatePickerRecorder alloc] init];
                [recorder recorder:datePicker attributes:attributes context:context nodes:nodes resources:resources];
            }
            case UIDatePickerStyleWheels:
            default:{
                FTWheelsStyleDatePickerRecorder *recorder =   [[FTWheelsStyleDatePickerRecorder alloc] init];
                [recorder recorder:datePicker attributes:attributes context:context nodes:nodes resources:resources];
            }
                break;
        }
    } else {
        FTWheelsStyleDatePickerRecorder *recorder =   [[FTWheelsStyleDatePickerRecorder alloc] init];
        [recorder recorder:datePicker attributes:attributes context:context nodes:nodes resources:resources];
    }
    BOOL isDisplayedInPopover = NO;
    if(view.superview){
        isDisplayedInPopover = [view.superview isKindOfClass:NSClassFromString(@"_UIVisualEffectContentView")];
    }
    FTUIDatePickerBuilder *builder = [[FTUIDatePickerBuilder alloc]init];
    builder.wireframeRect = attributes.frame;
    builder.attributes = attributes;
    builder.wireframeID = [context.viewIDGenerator SRViewID:view nodeRecorder:self];
    builder.isDisplayedInPopover = isDisplayedInPopover;
    [nodes insertObject:builder atIndex:0];
    FTSpecificElement *element = [[FTSpecificElement alloc]initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
    element.nodes = nodes;
    element.resources = resources;
    return element;
}
@end

@implementation FTUIDatePickerBuilder

- (NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect backgroundColor:self.isDisplayedInPopover?[FTSystemColors secondarySystemGroupedBackgroundColor]:[FTSystemColors systemBackgroundColor] cornerRadius:@(10) opacity:@(self.attributes.alpha)];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:self.isDisplayedInPopover?[FTSystemColors secondarySystemFillColor]:nil width:1];
    return @[wireframe];
}

@end

@interface FTWheelsStyleDatePickerRecorder()
@property (nonatomic, strong) FTViewTreeRecorder *subtreeRecorder;
@end
@implementation FTWheelsStyleDatePickerRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _subtreeRecorder = [[FTViewTreeRecorder alloc]init];
        FTUIPickerViewRecorder *recorder = [[FTUIPickerViewRecorder alloc]init];
        recorder.textObfuscator = ^id<FTSRTextObfuscatingProtocol> _Nullable(FTViewTreeRecordingContext * _Nonnull context) {
            return context.recorder.privacy.staticTextObfuscator;
        };
        _subtreeRecorder.nodeRecorders = @[
            recorder
        ];
    }
    return self;
}

-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources{
    return [self.subtreeRecorder record:nodes resources:resources view:view context:context];
}

@end
@interface FTInlineStyleDatePickerRecorder()
@property (nonatomic, strong) FTUIViewRecorder *viewRecorder;
@property (nonatomic, strong) FTUILabelRecorder *labelRecorder;
@property (nonatomic, strong) FTViewTreeRecorder *subtreeRecorder;
@end
@implementation FTInlineStyleDatePickerRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _viewRecorder = [[FTUIViewRecorder alloc]init];
        _labelRecorder = [[FTUILabelRecorder alloc]init];
        _labelRecorder.textObfuscator = ^id<FTSRTextObfuscatingProtocol>(FTViewTreeRecordingContext *context) {
            return context.recorder.privacy.staticTextObfuscator;
        };
        _subtreeRecorder = [[FTViewTreeRecorder alloc]init];
        _subtreeRecorder.nodeRecorders = @[
            _viewRecorder,
            _labelRecorder,
            [[FTUIImageViewRecorder alloc] init],
            [[FTUISegmentRecorder alloc] init],
        ];
    }
    return self;
}
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources{
    self.viewRecorder.semanticsOverride = ^FTSRNodeSemantics* _Nullable(UIView * _Nonnull view, FTViewAttributes * _Nonnull attributes) {
        if (context.recorder.privacy.shouldMaskInputElements) {
            BOOL isSquare = attributes.frame.size.width == attributes.frame.size.height;
            BOOL isCircle = isSquare && attributes.layerCornerRadius == attributes.frame.size.width * 0.5;
            if (isCircle) {
                FTIgnoredElement *element = [[FTIgnoredElement alloc]init];
                element.subtreeStrategy = NodeSubtreeStrategyIgnore;
                return element;
            }
        }
        return nil;
    };
    
    if(context.recorder.privacy.shouldMaskInputElements){
        self.labelRecorder.builderOverride = ^FTUILabelBuilder * _Nullable(FTUILabelBuilder *builder) {
            FTUILabelBuilder *labelBuilder = builder;
            labelBuilder.textColor = [FTSystemColors labelColorCGColor];
            return labelBuilder;
        };
    }
    return [self.subtreeRecorder record:nodes resources:resources view:view context:context];
}
@end
@interface FTCompactStyleDatePickerRecorder()
@property (nonatomic, strong) FTViewTreeRecorder *subtreeRecorder;
@end

@implementation FTCompactStyleDatePickerRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        _subtreeRecorder = [[FTViewTreeRecorder alloc]init];
        FTUILabelRecorder *labelRecorder = [[FTUILabelRecorder alloc]init];
        labelRecorder.textObfuscator = ^id<FTSRTextObfuscatingProtocol> _Nullable(FTViewTreeRecordingContext *context) {
            return context.recorder.privacy.staticTextObfuscator;
        };
        _subtreeRecorder.nodeRecorders = @[
            [[FTUIViewRecorder alloc] init],
            labelRecorder
        ];
    }
    return self;
}
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources{
    return [self.subtreeRecorder record:nodes resources:resources view:view context:context];
}
@end
