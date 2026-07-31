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
#if TARGET_OS_IOS || TARGET_OS_OSX

#import <Foundation/Foundation.h>
#import "FTSessionReplayPlatform.h"
#import <WebKit/WKWebView.h>
NS_ASSUME_NONNULL_BEGIN
@class FTSRContext,FTSRViewID,FTViewControllerContext,FTHeatmapCache,FTHeatmapIdentifier;
@interface FTViewTreeRecordingContext : NSObject
@property (nonatomic, strong) FTSRContext *recorder;
@property (nonatomic, strong) FTSRViewID *viewIDGenerator;
@property (nonatomic, strong) FTSRPlatformView *coordinateSpace;
@property (nonatomic, strong) FTViewControllerContext *viewControllerContext;
@property (nonatomic, strong, nullable) NSHashTable<WKWebView*> *webViewCache;
/// WKWebView slot identifiers emitted while recording the current snapshot.
@property (nonatomic, strong, nullable) NSMutableSet<NSNumber *> *webViewSlotIDs;
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
#if TARGET_OS_IOS
- (void)setParentTypeWithViewController:(UIViewController *)viewController;
#endif
@end

NS_ASSUME_NONNULL_END

#endif
