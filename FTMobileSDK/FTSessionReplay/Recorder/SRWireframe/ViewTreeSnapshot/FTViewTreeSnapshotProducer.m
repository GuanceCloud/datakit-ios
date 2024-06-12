//
//  FTViewTreeSnapshot.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTViewTreeSnapshotProducer.h"
#import "FTViewAttributes.h"
#import "FTSRViewID.h"
#import <SafariServices/SafariServices.h>
#import <WebKit/WebKit.h>
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

@interface FTViewTreeSnapshotProducer()
@property (nonatomic, strong) FTSRViewID *idGen;
@property (nonatomic, strong) FTImageDataUtils *imageDataProvider;
@property (nonatomic, strong) NSArray<id <FTSRWireframesRecorder>> *recorders;
@end
@implementation FTViewTreeSnapshotProducer
-(instancetype)init{
    self = [super init];
    if(self){
        _idGen = [[FTSRViewID alloc]init];
        _imageDataProvider = [[FTImageDataUtils alloc]init];
        _recorders = @[[FTUIViewRecorder new],
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
    FTViewTreeSnapshot *viewTree = [[FTViewTreeSnapshot alloc]init];
    viewTree.date = [NSDate date];
    viewTree.context = context;
    viewTree.viewportSize = rootView.frame.size;
    NSMutableArray *node = (NSMutableArray<id<FTSRWireframesBuilder>> *)[[NSMutableArray alloc]init];
    FTRecorderContext *recorderContext = [[FTRecorderContext alloc]init];
    recorderContext.viewIDGenerator = self.idGen;
    recorderContext.recorder = context;
    recorderContext.rootView = rootView;
    recorderContext.imageDataProvider = self.imageDataProvider;
    NSMutableArray *resource = [[NSMutableArray alloc]init];

    [self recordRecursively:node resources:resource view:rootView context:recorderContext];
    viewTree.nodes = node;
    return viewTree;
}
- (void)recordRecursively:(NSMutableArray *)nodes resources:(NSMutableArray *)resource view:(UIView *)view context:(FTRecorderContext *)context{
    FTViewAttributes *attribute = [[FTViewAttributes alloc]initWithFrameInRootView:[view convertRect:view.bounds toView:context.rootView] view:view];
    if (attribute.isVisible){
        return;
    }
    // 是否是不采集的控制器
    if ([view.nextResponder isKindOfClass:UIViewController.class]){
        if([self isBlackListViewController:(UIViewController *)view.nextResponder]){
            return;
        }
    }
    if ([view isKindOfClass:[WKWebView class]] || [view isKindOfClass:[UIProgressView class]] || [view isKindOfClass:[UIActivityIndicatorView class]]){
        return;
    }else{
        NSArray<id <FTSRWireframesBuilder>> *builders;
        for (id<FTSRWireframesRecorder> recorder in self.recorders) {
            NSArray<id <FTSRWireframesBuilder>> *newBuilders = [recorder recorder:view attributes:attribute context:context];
            if(newBuilders && newBuilders.count>0){
                builders = newBuilders;
            }
        }
        
        for (UIView *subView in view.subviews) {
            [self recordRecursively:nodes resources:resource view:subView context:context];
        }
    }
}
- (BOOL)isBlackListViewController:(UIViewController *)vc{
    static NSSet * blacklistedClasses  = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blacklistedClasses = [NSSet setWithArray:@[@"UIHostingController",@"SFSafariViewController",@"UIActivityViewController"]];
    });
    __block BOOL isContains = NO;
    [blacklistedClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *blackClassName = (NSString *)obj;
        Class blackClass = NSClassFromString(blackClassName);
        if (blackClass && [vc isKindOfClass:blackClass]) {
            isContains = YES;
            *stop = YES;
        }
    }];
    return isContains;
}
@end
