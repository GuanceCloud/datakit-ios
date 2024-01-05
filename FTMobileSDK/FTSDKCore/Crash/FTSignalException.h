//
//  FTSignalException.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTSignalException_h
#define FTSignalException_h
#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <mach/mach.h>

typedef void (*FTCrashNotifyCallback)(thread_t thread,uintptr_t*   backtrace,int count, const char *  crashMessage);

// TODO: 命名优化，避免函数命名冲突
void installSignalException(const FTCrashNotifyCallback onCrashNotify);

void uninstallSignalException(void);

#ifdef __cplusplus
}
#endif
#endif /* FTSignalException_h */
