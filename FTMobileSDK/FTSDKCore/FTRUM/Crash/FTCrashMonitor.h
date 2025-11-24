//
//  FTCrashMonitor.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/4.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashMonitor_h
#define FTCrashMonitor_h
#include "FTStackInfo.h"

#include <stdio.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef void (*FTCrashNotifyCallback)(FTThread thread,uintptr_t*   backtrace,int count, const char *  crashMessage);
/** Sets whether a crash is being handled and returns the previous state.
 *
 * @return The previous crash handling state
 */
bool ftcm_setCrashHandling(bool handling);
/**
 * Activates all added crash monitors.
 */
bool ftcm_activateMonitors(void);
/**
 * Disables all active crash monitors.
 *
 * Turns off all currently active monitors.
 */
void ftcm_disableAllMonitors(void);
/**
 * Sets the callback for event capture.
 *
 * @param onCrashNotify Callback function for events.
 *
 * Registers a callback to be invoked when an event occurs.
 */
void ftcm_setEventCallback(const FTCrashNotifyCallback onCrashNotify);
/**
 * Start general exception processing.
 */
void ftcm_handleException(FTThread thread,uintptr_t*backtrace,int count,const char *crashMessage);
#ifdef __cplusplus
}
#endif
#endif /* FTCrashMonitor_h */
