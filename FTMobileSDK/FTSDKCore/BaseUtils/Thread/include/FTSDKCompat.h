//
//  FTSDKCompat.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/3/22.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#include <TargetConditionals.h>

#ifdef __OBJC_GC__
    #error FTSDK does not support Objective-C Garbage Collection
#endif

#if TARGET_OS_OSX
    #define FT_MAC 1
#else
    #define FT_MAC 0
#endif

#if TARGET_OS_IOS
    #define FT_IOS 1
#else
    #define FT_IOS 0
#endif

#if TARGET_OS_TV || TARGET_OS_IOS
   #define FT_HAS_UIKIT 1
#else
   #define FT_HAS_UIKIT 0
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX
#define FT_HAS_SIGNAL_STACK 1
#else
#define FT_HAS_SIGNAL_STACK 0
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX
#define FT_HAS_MACH 1
#else
#define FT_HAS_MACH 0
#endif

