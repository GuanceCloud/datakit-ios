//
//  FTSDKCompat.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/3/22.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#ifdef __APPLE__
#include <TargetConditionals.h>
#define FT_HOST_APPLE 1
#endif

#ifdef __OBJC_GC__
    #error FTSDK does not support Objective-C Garbage Collection
#endif

#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
#define FTCRASH_HOST_VISION 1
#else
#define FTCRASH_HOST_VISION 0
#endif

#define FT_HOST_IOS TARGET_OS_IOS
#define FT_HOST_TV TARGET_OS_TV
#define FT_HOST_WATCH TARGET_OS_WATCH
#define FT_HOST_VISION TARGET_OS_VISION
#define FT_HOST_MAC                                                                            \
    (TARGET_OS_MAC && !(TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH || TARGET_OS_VISION))

#if FT_HOST_APPLE
#define FTCRASH_CAN_GET_MAC_ADDRESS 1
#else
#define FTCRASH_CAN_GET_MAC_ADDRESS 0
#endif

#if FT_HOST_APPLE
#define FT_HAS_OBJC 1
#define FT_HAS_SWIFT 1
#else
#define FT_HAS_OBJC 0
#define FT_HAS_SWIFT 0
#endif

#if FT_HOST_APPLE
#define FT_HAS_STRNSTR 1
#else
#define FT_HAS_STRNSTR 0
#endif

#if FT_HOST_IOS || FT_HOST_TV || FT_HOST_VISION
#define FT_HAS_UIDEVICE 1
#else
#define FT_HAS_UIDEVICE 0
#endif


#if FT_HOST_MAC || FT_HOST_IOS || FT_HOST_TV || FT_HOST_VISION
#define FT_HAS_THREADS_API 1
#else
#define FT_HAS_THREADS_API 0
#endif


#if FT_HOST_IOS || FT_HOST_TV || FT_HOST_VISION
#define FT_HAS_UIDEVICE 1
#else
#define FT_HAS_UIDEVICE 0
#endif

#if TARGET_OS_TV || TARGET_OS_IOS || FT_HOST_WATCH || FT_HOST_VISION
   #define FT_HAS_UIKIT 1
#else
   #define FT_HAS_UIKIT 0
#endif

#if  FT_HOST_IOS || FT_HOST_MAC || FT_HOST_TV || FT_HOST_VISION
#define FT_HAS_SIGNAL 1
#else
#define FT_HAS_SIGNAL 0
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

#if FT_HOST_MAC || FT_HOST_IOS || FT_HOST_TV || FT_HOST_VISION
#define FTCRASH_HAS_THREADS_API 1
#else
#define FTCRASH_HAS_THREADS_API 0
#endif
