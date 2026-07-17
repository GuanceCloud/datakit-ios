//
//  UIView+FTSR.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/3.
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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (FTSR)
@property(nonatomic, strong) NSDictionary* SRNodeID;
@property(nonatomic, strong) NSDictionary* SRNodeIDs;
@property(nonatomic, assign, readonly) BOOL usesDarkMode;
@end

NS_ASSUME_NONNULL_END

#endif
