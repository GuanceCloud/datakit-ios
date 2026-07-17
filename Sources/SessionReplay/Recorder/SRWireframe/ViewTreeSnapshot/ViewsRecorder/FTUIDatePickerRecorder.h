//
//  FTUIDatePickerRecorder.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/30.
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
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes,FTViewTreeRecorder;
NS_ASSUME_NONNULL_BEGIN
@interface FTUIDatePickerBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) BOOL isDisplayedInPopover;
@end
@interface FTUIDatePickerRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
-(instancetype)initWithIdentifier:(NSString *)identifier;
@end
@interface FTWheelsStyleDatePickerRecorder : NSObject
-(instancetype)initWithIdentifier:(NSString *)identifier;
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources;
@end
@interface FTInlineStyleDatePickerRecorder : NSObject
-(instancetype)initWithIdentifier:(NSString *)identifier;
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources;
@end

@interface FTCompactStyleDatePickerRecorder : NSObject
-(instancetype)initWithIdentifier:(NSString *)identifier;
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources;
@end
NS_ASSUME_NONNULL_END

#endif
