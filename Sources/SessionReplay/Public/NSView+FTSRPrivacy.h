//
//  NSView+FTSRPrivacy.h
//  SessionReplay
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import <AppKit/AppKit.h>
#import "FTSessionReplayPrivacyOverrides.h"

NS_ASSUME_NONNULL_BEGIN

/// Provides per-view Session Replay privacy overrides for AppKit views.
@interface NSView (FTSRPrivacy)

/// Privacy settings inherited by descendants unless they provide an override.
@property (nonatomic, strong, readonly) FTSessionReplayPrivacyOverrides *sessionReplayPrivacyOverrides;

@end

NS_ASSUME_NONNULL_END

#endif
