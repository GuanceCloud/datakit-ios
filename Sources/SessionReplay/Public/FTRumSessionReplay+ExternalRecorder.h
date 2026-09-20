//
//  FTRumSessionReplay+ExternalRecorder.h
//  SessionReplay
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTRumSessionReplay.h"

NS_ASSUME_NONNULL_BEGIN

/// Integration APIs for framework-owned Session Replay recorders.
///
/// These APIs are intended for framework SDK adapters and are not part of the
/// application-facing Session Replay API.
@interface FTRumSessionReplay (ExternalRecorder)

/// Returns the active RUM application, session, view, and linked context for an
/// external Session Replay recorder. Returns nil while replay is not sampled.
- (nullable NSDictionary<NSString *, id> *)currentExternalRUMContext;

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
