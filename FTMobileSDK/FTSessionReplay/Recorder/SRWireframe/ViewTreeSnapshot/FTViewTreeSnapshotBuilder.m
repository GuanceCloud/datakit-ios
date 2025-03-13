//
//  FTViewTreeSnapshotBuilder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTViewTreeSnapshotBuilder.h"
#import "FTViewAttributes.h"
#import "FTSRViewID.h"
#import "FTViewTreeRecordingContext.h"
#import <SafariServices/SafariServices.h>
#import "FTUINavigationBarRecorder.h"
#import "FTUIViewRecorder.h"
#import "FTUINavigationBarRecorder.h"
#import "FTUITabBarRecorder.h"
#import "FTUIStepperRecorder.h"
#import "FTUISliderRecorder.h"
#import "FTUISwitchRecorder.h"
#import "FTUISegmentRecorder.h"
#import "FTUILabelRecorder.h"
#import "FTUITextFieldRecorder.h"
#import "FTUITextViewRecorder.h"
#import "FTUIImageViewRecorder.h"
#import "FTUIPickerViewRecorder.h"
#import "FTUIDatePickerRecorder.h"
#import "FTViewTreeRecorder.h"
#import "FTUnsupportedViewRecorder.h"
#import "FTUIProgressViewRecorder.h"
#import "FTUIActivityIndicatorRecorder.h"

@interface FTViewTreeSnapshotBuilder()
@property (nonatomic, strong) FTViewTreeRecorder *viewTreeRecorder;
@property (nonatomic, strong) FTSRViewID *idGen;
@property (nonatomic, strong) FTImageDataUtils *imageDataProvider;
@end
@implementation FTViewTreeSnapshotBuilder
-(instancetype)init{
    return [self initWithAdditionalNodeRecorders:nil];
}
-(instancetype)initWithAdditionalNodeRecorders:(NSArray <id <FTSRWireframesRecorder>>*)additionalNodeRecorders{
    self = [super init];
    if(self){
        _idGen = [[FTSRViewID alloc]init];
        _imageDataProvider = [[FTImageDataUtils alloc]init];
        _viewTreeRecorder = [[FTViewTreeRecorder alloc] init];
        if(additionalNodeRecorders.count>0){
            NSMutableArray<id <FTSRWireframesRecorder>> *recorders = [NSMutableArray arrayWithArray:[self createDefaultNodeRecorders]];
            [recorders addObjectsFromArray:additionalNodeRecorders];
            _viewTreeRecorder.nodeRecorders = recorders;
        }else{
            _viewTreeRecorder.nodeRecorders = [self createDefaultNodeRecorders];
        }
    }
    return self;
}
- (FTViewTreeSnapshot *)takeSnapshot:(NSArray <UIView *> *)rootViews context:(FTSRContext *)context{
    NSMutableArray *node = [[NSMutableArray alloc]init];
    NSMutableArray *resource = [[NSMutableArray alloc]init];
    for (UIView *rootView in rootViews) {
        // 判断 window 是否可以显示
        if(rootView.isHidden == NO && rootView.alpha>0 && !CGRectEqualToRect(rootView.frame, CGRectZero)){
            FTViewTreeRecordingContext *recordingContext = [[FTViewTreeRecordingContext alloc]init];
            recordingContext.viewIDGenerator = self.idGen;
            recordingContext.recorder = context;
            recordingContext.coordinateSpace = [UIScreen mainScreen].coordinateSpace;
            recordingContext.clip = UIScreen.mainScreen.bounds;
            recordingContext.viewControllerContext = [FTViewControllerContext new];
            [self.viewTreeRecorder record:node resources:resource view:rootView context:recordingContext];
        }
    }
    FTViewTreeSnapshot *viewTree = [[FTViewTreeSnapshot alloc]init];
    viewTree.date = context.date;
    viewTree.context = context;
    viewTree.viewportSize = UIScreen.mainScreen.bounds.size;
    viewTree.nodes = node;
    viewTree.resources = resource;
    return viewTree;
}
- (NSArray <id <FTSRWireframesRecorder>> *)createDefaultNodeRecorders{
    return @[
        [FTUnsupportedViewRecorder new],
        [FTUIViewRecorder new],
        [FTUILabelRecorder new],
        [FTUIImageViewRecorder new],
        [FTUITextFieldRecorder new],
        [FTUITextViewRecorder new],
        [FTUISwitchRecorder new],
        [FTUISliderRecorder new],
        [FTUISegmentRecorder new],
        [FTUIStepperRecorder new],
        [FTUINavigationBarRecorder new],
        [FTUITabBarRecorder new],
        [FTUIPickerViewRecorder new],
        [FTUIDatePickerRecorder new],
        [FTUIProgressViewRecorder new],
        [FTUIActivityIndicatorRecorder new],
    ];
}
@end
