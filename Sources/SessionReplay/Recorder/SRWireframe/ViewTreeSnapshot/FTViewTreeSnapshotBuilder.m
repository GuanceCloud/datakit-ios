//
//  FTViewTreeSnapshotBuilder.m
//  SessionReplay
//
//  Created by hulilei on 2023/7/17.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTViewTreeSnapshotBuilder.h"
#import "FTViewAttributes.h"
#import "FTSRViewID.h"
#import "FTViewTreeRecordingContext.h"
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
#import "FTUIHostingViewRecorder.h"
#import "FTUIPickerViewRecorder.h"
#import "FTUIDatePickerRecorder.h"
#import "FTViewTreeRecorder.h"
#import "FTUnsupportedViewRecorder.h"
#import "FTUIProgressViewRecorder.h"
#import "FTUIActivityIndicatorRecorder.h"
#import "FTSessionReplayCoreImports.h"
#if !TARGET_OS_TV
#import "FTWKWebViewRecorder.h"
#endif
@interface FTViewTreeSnapshotBuilder()
@property (nonatomic, strong) FTViewTreeRecorder *viewTreeRecorder;
@property (nonatomic, strong) FTSRViewID *idGen;
@end
@implementation FTViewTreeSnapshotBuilder
-(instancetype)init{
    return [self initWithAdditionalNodeRecorders:nil];
}
-(instancetype)initWithAdditionalNodeRecorders:(NSArray <id <FTSRWireframesRecorder>>*)additionalNodeRecorders{
    return [self initWithAdditionalNodeRecorders:additionalNodeRecorders enableSwiftUI:NO];
}
-(instancetype)initWithAdditionalNodeRecorders:(NSArray <id <FTSRWireframesRecorder>>*)additionalNodeRecorders enableSwiftUI:(BOOL)enableSwiftUI{
    self = [super init];
    if(self){
        _idGen = [[FTSRViewID alloc]init];
        _viewTreeRecorder = [[FTViewTreeRecorder alloc] init];
        _webViewCache = [NSHashTable weakObjectsHashTable];
        if(additionalNodeRecorders.count>0){
            NSMutableArray<id <FTSRWireframesRecorder>> *recorders = [NSMutableArray arrayWithArray:[self createDefaultNodeRecordersWithSwiftUIEnabled:enableSwiftUI]];
            [recorders addObjectsFromArray:additionalNodeRecorders];
            _viewTreeRecorder.nodeRecorders = recorders;
        }else{
            _viewTreeRecorder.nodeRecorders = [self createDefaultNodeRecordersWithSwiftUIEnabled:enableSwiftUI];
        }
        _recorders = _viewTreeRecorder.nodeRecorders;
    }
    return self;
}
- (FTViewTreeSnapshot *)takeSnapshot:(NSArray <UIView *> *)rootViews referenceView:(UIView *)referenceView context:(FTSRContext *)context{
    NSMutableArray *node = [[NSMutableArray alloc]init];
    NSMutableArray *resource = [[NSMutableArray alloc]init];
    FTHeatmapCache *heatmapCache = self.enableHeatmap ? [[FTHeatmapCache alloc]init] : nil;
    NSArray<NSNumber *> *rootTypeIndices = [self typeIndicesForViews:rootViews];
    for (NSUInteger index = 0; index < rootViews.count; index++) {
        UIView *rootView = rootViews[index];
        // Determine if window can be displayed
        if(rootView.isHidden == NO && rootView.alpha>0 && !CGRectEqualToRect(rootView.frame, CGRectZero)){
            FTViewTreeRecordingContext *recordingContext = [[FTViewTreeRecordingContext alloc]init];
            recordingContext.viewIDGenerator = self.idGen;
            recordingContext.recorder = context;
            recordingContext.webViewCache = self.webViewCache;
            recordingContext.coordinateSpace = referenceView;
            recordingContext.clip = referenceView.bounds;
            recordingContext.viewControllerContext = [FTViewControllerContext new];
            recordingContext.heatmapCache = heatmapCache;
            recordingContext.nodePath = [NSMutableArray array];
            [self.viewTreeRecorder record:node view:rootView context:recordingContext typeIndex:[rootTypeIndices[index] integerValue]];
        }
    }
    if (heatmapCache) {
        id<FTHeatmapIdentifierRegistry> registry = [[FTModuleManager sharedInstance] getRegisterService:@protocol(FTHeatmapIdentifierRegistry)];
        [registry setHeatmapIdentifiers:[heatmapCache.identifiers copy]];
    }
    FTViewTreeSnapshot *viewTree = [[FTViewTreeSnapshot alloc]init];
    viewTree.date = context.date;
    viewTree.context = context;
    viewTree.viewportSize = referenceView.bounds.size;
    viewTree.nodes = node;
    NSArray *webViews = [self.webViewCache allObjects];
    NSMutableArray *hashes = [NSMutableArray arrayWithCapacity:webViews.count];
    for (WKWebView *webView in webViews) {
        [hashes addObject:@(webView.hash)];
    }
    viewTree.webViewSlotIDs = [NSSet setWithArray:hashes];
    viewTree.resources = resource;
    return viewTree;
}
- (NSArray<NSNumber *> *)typeIndicesForViews:(NSArray<UIView *> *)views {
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    NSMutableArray<NSNumber *> *indices = [NSMutableArray arrayWithCapacity:views.count];
    for (UIView *view in views) {
        NSString *className = NSStringFromClass(view.class);
        NSInteger index = [counts[className] integerValue];
        [indices addObject:@(index)];
        counts[className] = @(index + 1);
    }
    return indices;
}
- (NSArray <id <FTSRWireframesRecorder>> *)createDefaultNodeRecordersWithSwiftUIEnabled:(BOOL)enableSwiftUI{
    NSMutableArray *recorders = @[
        [[FTUnsupportedViewRecorder alloc] initWithSwiftUIEnabled:enableSwiftUI],
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
#if !TARGET_OS_TV
        [FTWKWebViewRecorder new],
#endif
        [FTUIProgressViewRecorder new],
        [FTUIActivityIndicatorRecorder new],
    ].mutableCopy;
    if (@available(iOS 13.0, *)) {
        if (enableSwiftUI) {
            [recorders addObject:[FTUIHostingViewRecorder new]];
        }
    }
    return [recorders copy];
}
@end

#endif
