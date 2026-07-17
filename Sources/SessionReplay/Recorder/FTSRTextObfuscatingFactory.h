//
//  FTSRTextObfuscatingFactory.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/12.
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
#import "FTRumSessionReplay.h"
typedef FTTextAndInputPrivacyLevel TextAndInputPrivacy;
NS_ASSUME_NONNULL_BEGIN
@protocol FTSRTextObfuscatingProtocol <NSObject>

- (NSString *)mask:(NSString *)text;

@end
@interface FTSRTextObfuscatingFactory : NSObject
+ (id<FTSRTextObfuscatingProtocol>)sensitiveTextObfuscator:(TextAndInputPrivacy)privacy;
+ (id<FTSRTextObfuscatingProtocol>)inputAndOptionTextObfuscator:(TextAndInputPrivacy)privacy;
+ (id<FTSRTextObfuscatingProtocol>)staticTextObfuscator:(TextAndInputPrivacy)privacy;
+ (id<FTSRTextObfuscatingProtocol>)hintTextObfuscator:(TextAndInputPrivacy)privacy;
+ (BOOL)shouldMaskInputElements:(TextAndInputPrivacy)privacy;

@end

@interface FTNOPTextObfuscator : NSObject <FTSRTextObfuscatingProtocol>
@end
@interface FTFixLengthMaskObfuscator : NSObject<FTSRTextObfuscatingProtocol>

@end

@interface FTSpacePreservingMaskObfuscator : NSObject<FTSRTextObfuscatingProtocol>
@end
NS_ASSUME_NONNULL_END

#endif
