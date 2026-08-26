//
//  FTRumSessionReplay.h
//  SessionReplay
//
//  Created by hulilei on 2022/12/23.
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
#import "FTSessionReplayConfig.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTRumSessionReplay : NSObject

/// Singleton
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());;

/// Configure Config to enable Session Replay
/// - Parameter config: Session Replay configuration items
- (void)startWithSessionReplayConfig:(FTSessionReplayConfig *)config;

/// Returns the active RUM application, session, view, and linked context for an
/// external Session Replay recorder. Returns nil while replay is not sampled.
- (nullable NSDictionary *)currentExternalRUMContext;

/// Pauses or resumes native view recording for the default external recorder.
/// Sampling, RUM linkage, storage, and upload remain active while paused.
- (void)setExternalRecorderActive:(BOOL)active;

/// Updates recorder ownership for a framework or engine instance. Native view
/// recording resumes only after every active owner has released ownership.
- (void)setExternalRecorderActive:(BOOL)active forOwner:(NSString *)owner;

/// Updates the RUM session replay flag.
- (void)setExternalHasReplay:(BOOL)hasReplay;

/// Updates the accumulated external record count for a RUM view.
- (void)setExternalRecordCountForViewID:(NSString *)viewID count:(NSUInteger)count;

/// Writes a framework-generated enriched record JSON segment.
- (void)writeExternalSegment:(NSString *)segment viewID:(NSString *)viewID;

/// Stores an encoded image resource and returns its content identifier.
- (nullable NSString *)saveExternalImageResourceData:(NSData *)data mimeType:(NSString *)mimeType;
@end

NS_ASSUME_NONNULL_END

#endif
