//
//  FTTLV.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/24.
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
extern NSUInteger const FT_MAX_DATA_LENGTH;

NS_ASSUME_NONNULL_BEGIN

@interface FTTLV : NSObject
@property (nonatomic, assign) uint16_t type;
@property (nonatomic, strong) NSData *value;
-(instancetype)initWithType:(uint16_t)type value:(NSData *)value;
- (nullable NSData *)serialize;
- (nullable NSData *)serialize:(UInt64)maxLength;
@end

NS_ASSUME_NONNULL_END

#endif
