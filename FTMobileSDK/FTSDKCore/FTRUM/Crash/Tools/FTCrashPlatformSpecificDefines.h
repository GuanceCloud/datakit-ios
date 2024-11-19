//
//  FTCrashPlatformSpecificDefines.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashPlatformSpecificDefines_h
#define FTCrashPlatformSpecificDefines_h

#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#    define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else /* __LP64__ */
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#    define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif /* __LP64__ */

#endif /* FTCrashPlatformSpecificDefines_h */
