//
//  FTQueue.h
//  SessionReplay
//
//  Created by hulilei on 2026/3/2.
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

NS_ASSUME_NONNULL_BEGIN
@protocol FTQueue <NSObject>

- (void)run:(void (^)(void))block;

@end

@interface FTAsyncQueue : NSObject <FTQueue>

@property (nonatomic, strong) dispatch_queue_t queue;

- (instancetype)initWithQueue:(dispatch_queue_t)queue;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface FTBackgroundAsyncQueue : FTAsyncQueue


- (instancetype)initWithLabel:(NSString *)label
                          qos:(qos_class_t)qos
                   attributes:(dispatch_queue_attr_t)attributes
         autoreleaseFrequency:(dispatch_autorelease_frequency_t)autoreleaseFrequency
                       target:(nullable FTAsyncQueue *)target NS_DESIGNATED_INITIALIZER;


- (instancetype)initWithLabel:(NSString *)label;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface FTMainQueue : NSObject <FTQueue>

@end


NS_ASSUME_NONNULL_END

#endif
