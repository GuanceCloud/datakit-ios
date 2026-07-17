//
//  FTFileWriter.h
//  SessionReplay
//
//  Created by hulilei on 2024/6/25.
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
@protocol FTAbstractJSONModelProtocol,FTFilesOrchestratorType;
@protocol FTWriter <NSObject>
- (void)write:(NSData *)datas;
- (void)write:(NSData *)datas forceNewFile:(BOOL)update;

@end
@protocol FTCacheWriter <NSObject,FTWriter>
- (void)active;
- (void)inactive;
- (void)cleanup;
@end
@interface FTFileWriter : NSObject<FTWriter>
-(instancetype)initWithOrchestrator:(id<FTFilesOrchestratorType>)orchestrator queue:(dispatch_queue_t)queue;
@end

NS_ASSUME_NONNULL_END

#endif
