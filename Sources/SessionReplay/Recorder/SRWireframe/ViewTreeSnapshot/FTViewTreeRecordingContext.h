//
//  FTViewTreeRecordingContext.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WKWebView.h>
NS_ASSUME_NONNULL_BEGIN
@class FTSRContext,FTSRViewID,FTViewControllerContext,FTHeatmapCache,FTHeatmapIdentifier;
@interface FTViewTreeRecordingContext : NSObject
@property (nonatomic, strong) FTSRContext *recorder;
@property (nonatomic, strong) FTSRViewID *viewIDGenerator;
@property (nonatomic, strong) id<UICoordinateSpace> coordinateSpace;
@property (nonatomic, strong) FTViewControllerContext *viewControllerContext;
@property (nonatomic, strong, nullable) NSHashTable<WKWebView*> *webViewCache;
@property (nonatomic, strong, nullable) FTHeatmapCache *heatmapCache;
@property (nonatomic, strong) NSMutableArray<NSString *> *nodePath;

@property (nonatomic, assign) CGRect clip;
@end

@interface FTHeatmapCache : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSValue *, FTHeatmapIdentifier *> *identifiers;
@end

typedef NS_ENUM(NSUInteger,ViewControllerType){
    ViewControllerTypeAlert,
    ViewControllerTypeSafari,
    ViewControllerTypeActivity,
    ViewControllerTypeSwiftUI,
    ViewControllerTypeOther
};
@interface FTViewControllerContext : NSObject
@property (nonatomic, assign) BOOL isRootView;
@property (nonatomic, assign) ViewControllerType parentType;
- (BOOL)isRootView:(ViewControllerType)type;
- (nullable NSString *)name;
- (void)setParentTypeWithViewController:(UIViewController *)viewController;
@end

NS_ASSUME_NONNULL_END

#endif
