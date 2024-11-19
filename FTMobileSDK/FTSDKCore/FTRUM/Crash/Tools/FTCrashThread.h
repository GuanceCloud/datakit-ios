//
//  FTCrashThread.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashThread_h
#define FTCrashThread_h

#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif
typedef uintptr_t FTCrashThread;

bool ftcrashthread_getThreadName(
    const FTCrashThread thread, char *const buffer, int bufLength);

FTCrashThread ftcrashthread_self(void);

#ifdef __cplusplus
}
#endif
#endif /* FTCrashThread_h */
