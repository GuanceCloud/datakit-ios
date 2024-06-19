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
#import "FTMobileConfig.h"
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

@interface FTViewTreeSnapshotBuilder()
@property (nonatomic, strong) FTViewTreeRecorder *viewTreeRecorder;
@property (nonatomic, strong) FTSRViewID *idGen;
@property (nonatomic, strong) FTImageDataUtils *imageDataProvider;
@end
@implementation FTViewTreeSnapshotBuilder
-(instancetype)init{
    self = [super init];
    if(self){
        _idGen = [[FTSRViewID alloc]init];
        _imageDataProvider = [[FTImageDataUtils alloc]init];
        _viewTreeRecorder = [[FTViewTreeRecorder alloc] init];
        _viewTreeRecorder.nodeRecorders = @[
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
        ];
    }
    return self;
}
- (FTViewTreeSnapshot *)takeSnapshot:(UIView *)rootView context:(FTSRContext *)context{
    FTViewTreeRecordingContext *recordingContext = [[FTViewTreeRecordingContext alloc]init];
    recordingContext.viewIDGenerator = self.idGen;
    recordingContext.recorder = context;
    recordingContext.coordinateSpace = rootView;
    recordingContext.viewControllerContext = [FTViewControllerContext new];
    NSMutableArray *node = [[NSMutableArray alloc]init];
    NSMutableArray *resource = [[NSMutableArray alloc]init];
    [self.viewTreeRecorder record:node resources:resource view:rootView context:recordingContext];
    FTViewTreeSnapshot *viewTree = [[FTViewTreeSnapshot alloc]init];
    viewTree.date = [NSDate date];
    viewTree.context = context;
    viewTree.viewportSize = rootView.bounds.size;
    viewTree.nodes = node;
    viewTree.resources = resource;
    return viewTree;
}
@end
