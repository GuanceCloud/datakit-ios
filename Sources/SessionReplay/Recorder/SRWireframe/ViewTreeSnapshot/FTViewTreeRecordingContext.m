//
//  FTViewTreeRecordingContext.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/13.
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

#import "FTViewTreeRecordingContext.h"
#import <SafariServices/SafariServices.h>
#import <SwiftUI/SwiftUI.h>
@implementation FTHeatmapCache
- (instancetype)init {
    self = [super init];
    if (self) {
        _identifiers = [NSMutableDictionary dictionary];
    }
    return self;
}
@end

@implementation FTViewTreeRecordingContext
- (instancetype)copyWithZone:(NSZone *)zone {
    FTViewTreeRecordingContext *options = [[[self class] allocWithZone:zone] init];
    options.recorder = self.recorder;
    options.viewIDGenerator = self.viewIDGenerator;
    options.coordinateSpace = self.coordinateSpace;
    options.viewControllerContext = self.viewControllerContext;
    options.clip = self.clip;
    options.webViewCache = self.webViewCache;
    options.heatmapCache = self.heatmapCache;
    options.nodePath = self.nodePath ? [self.nodePath mutableCopy] : [NSMutableArray array];
    return options;
}
@end
@implementation FTViewControllerContext
- (NSString *)name{
    if(!self.isRootView){
        return nil;
    }
    switch (self.parentType) {
        case ViewControllerTypeAlert:
            return @"Alert";
        case ViewControllerTypeSafari:
            return @"Safari";
        case ViewControllerTypeActivity:
            return @"Activity";
        case ViewControllerTypeSwiftUI:
            return @"SwiftUI";
        case ViewControllerTypeOther:
            return nil;
    }
}
- (BOOL)isRootView:(ViewControllerType)type {
    return self.parentType == type && self.isRootView == YES;
}
- (void)setParentTypeWithViewController:(UIViewController *)viewController{
    if([viewController isKindOfClass:UIAlertController.class]){
        self.parentType = ViewControllerTypeAlert;
    }else if ([viewController isKindOfClass:UIActivityViewController.class]){
        self.parentType = ViewControllerTypeActivity;
    }else if ([viewController isKindOfClass:SFSafariViewController.class]){
        self.parentType = ViewControllerTypeSafari;
    }else if([FTViewControllerContext isSwiftUIViewController:viewController]){
        self.parentType = ViewControllerTypeSwiftUI;
    }else{
        self.parentType = ViewControllerTypeOther;
    }
}
+ (BOOL)isSwiftUIViewController:(UIViewController *)viewController{
    NSString *bundleName = [NSBundle bundleForClass:viewController.class].bundleURL.lastPathComponent;
    if ([bundleName isEqualToString:@"SwiftUI.framework"]) {
        return YES;
    }
    NSString *className = NSStringFromClass(viewController.class);
    return [className hasPrefix:@"SwiftUI."] || [className hasPrefix:@"_TtC7SwiftUI"] || [className hasPrefix:@"_TtGC7SwiftUI"] || [className containsString:@"UIHostingController"];
}
@end

#endif
