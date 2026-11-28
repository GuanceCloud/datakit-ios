//
//  FTSessionReplayConfig+FrameworkIntegration.h
//  SessionReplay
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//  Licensed under the Apache License, Version 2.0 (the "License");
//

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#import "FTSessionReplayConfig.h"
#import "FTSRNodeWireframesBuilder.h"

NS_ASSUME_NONNULL_BEGIN

/// Configuration for framework integrations such as React Native and Flutter.
@interface FTSessionReplayConfig (FrameworkIntegration)

/// Additional recorders for native views. Default: nil.
/// Set before starting Session Replay. Ignored when externalRecorderMode is enabled.
@property (nonatomic, strong, nullable) NSArray<id<FTSRWireframesRecorder>> *additionalNodeRecorders;

/// Enables external-only recorder mode. Default: NO.
///
/// In this mode the SDK keeps Session Replay sampling, storage, resource upload,
/// and RUM linkage active, but does not capture the native view hierarchy. A
/// framework SDK can supply its own enriched records and image resources through
/// `FTRumSessionReplay`. Hybrid integrations that switch between native and
/// framework screens should keep this disabled and use
/// `setExternalRecorderActive:` at runtime.
@property (nonatomic, assign) BOOL externalRecorderMode;

@end

NS_ASSUME_NONNULL_END

#endif
