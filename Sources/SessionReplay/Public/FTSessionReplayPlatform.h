//
//  FTSessionReplayPlatform.h
//  SessionReplay
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

typedef UIView FTSRPlatformView;
typedef UIWindow FTSRPlatformWindow;
typedef UIColor FTSRPlatformColor;
typedef UIImage FTSRPlatformImage;
typedef UIFont FTSRPlatformFont;
typedef UIEdgeInsets FTSRPlatformEdgeInsets;

#elif TARGET_OS_OSX

#import <AppKit/AppKit.h>

typedef NSView FTSRPlatformView;
typedef NSWindow FTSRPlatformWindow;
typedef NSColor FTSRPlatformColor;
typedef NSImage FTSRPlatformImage;
typedef NSFont FTSRPlatformFont;
typedef NSEdgeInsets FTSRPlatformEdgeInsets;

#endif
