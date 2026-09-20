//
//  FTSessionReplayConfig+ExternalRecorder.h
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

#import "FTSessionReplayConfig.h"

NS_ASSUME_NONNULL_BEGIN

/// Configuration used by framework-owned Session Replay recorders.
@interface FTSessionReplayConfig (ExternalRecorder)

/// Enables external-only recorder mode. Default: NO.
///
/// In this mode the SDK keeps Session Replay sampling, storage, resource upload,
/// and RUM linkage active, but does not capture the native view hierarchy. A
/// framework SDK can supply its own enriched records and image resources through
/// `FTRumSessionReplay (ExternalRecorder)`. Hybrid integrations that switch
/// between native and framework screens should keep this disabled and update
/// recorder ownership with `setExternalRecorderActive:forOwner:` at runtime.
@property (nonatomic, assign) BOOL externalRecorderMode;

@end

NS_ASSUME_NONNULL_END

#endif
