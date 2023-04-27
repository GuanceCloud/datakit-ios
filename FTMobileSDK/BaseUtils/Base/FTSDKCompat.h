//
//  FTSDKCompat.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/3/22.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <TargetConditionals.h>

#ifdef __OBJC_GC__
    #error FTSDK does not support Objective-C Garbage Collection
#endif

#if TARGET_OS_OSX
    #define FT_MAC 1
#else
    #define FT_MAC 0
#endif

#if TARGET_OS_IOS
    #define FT_UIKIT 1
#else
    #define FT_UIKIT 0
#endif

#if FT_MAC
    #import <AppKit/AppKit.h>
#else
    #if FT_UIKIT
        #import <UIKit/UIKit.h>
    #endif
#endif


