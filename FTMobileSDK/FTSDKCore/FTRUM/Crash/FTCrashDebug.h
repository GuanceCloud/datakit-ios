//
//  FTCrashDebug.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/4.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashDebug_h
#define FTCrashDebug_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Check if the current process is being traced or not.
 *
 * @return true if we're being traced.
 */
bool ftdebug_isBeingTraced(void);

#ifdef __cplusplus
}
#endif

#endif /* FTCrashDebug_h */
