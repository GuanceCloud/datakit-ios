//
//  FTStackCursor_MachineContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTStackCursor_MachineContext_h
#define FTStackCursor_MachineContext_h
#include "FTStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif
#define MAX_STACKTRACE_LENGTH 100

void ftsc_initWithMachineContext(FTStackCursor *cursor, int maxStackDepth,
                                 const struct FTCrashMachineContext *machineContext);

#ifdef __cplusplus
}
#endif
#endif /* FTStackCursor_MachineContext_h */
