//
//  FTSessionReplayPrivacyOverrides+Extension.h
//  SessionReplay
//
//  Created by hulilei on 2025/3/11.
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

#import "FTSessionReplayPrivacyOverrides.h"

NS_ASSUME_NONNULL_BEGIN
typedef FTSessionReplayPrivacyOverrides PrivacyOverrides;

@interface FTSessionReplayPrivacyOverrides ()
@property (nonatomic, strong, nullable) NSNumber *nImagePrivacy;
@property (nonatomic, strong, nullable) NSNumber *nTouchPrivacy;
@property (nonatomic, strong, nullable) NSNumber *nTextAndInputPrivacy;
+ (PrivacyOverrides *)mergeChild:(PrivacyOverrides *)child parent:(PrivacyOverrides *)parent;
@end

NS_ASSUME_NONNULL_END

#endif
