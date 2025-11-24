//
//  FTCrashMonitor.c
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/4.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#include "FTCrashMonitor.h"
#include "FTCrashDebug.h"
#include "FTCrashLogger.h"
#include "FTNSException.h"
#include "FTSignalException.h"
#include "FTMachException.h"
#include <os/lock.h>

static os_unfair_lock g_monitorsLock = OS_UNFAIR_LOCK_INIT;
static bool g_crashIsHandling = false;

static void (*g_onExceptionEvent)(FTThread thread,uintptr_t*backtrace,int count,const char *crashMessage);

bool ftcm_activateMonitors(void){
    // Check for debugger and async safety
    bool isDebuggerUnsafe = ftdebug_isBeingTraced();
    
    if (isDebuggerUnsafe) {
        static bool hasWarned = false;
        if (!hasWarned) {
            hasWarned = true;
            FTLOG_WARN("    ************************ Crash Handler Notice ************************");
            FTLOG_WARN("    *     App is running in a debugger. Masking out unsafe monitors.     *");
            FTLOG_WARN("    * This means that most crashes WILL NOT BE RECORDED while debugging! *");
            FTLOG_WARN("    **********************************************************************");
        }
    }
    FTInstallUncaughtExceptionHandler();
    if (!isDebuggerUnsafe) {
        FTInstallMachException();
        FTInstallSignalException();
    }
    return true;
}

void ftcm_disableAllMonitors(void){
    os_unfair_lock_lock(&g_monitorsLock);
    FTUninstallSignalException();
    FTUninstallUncaughtExceptionHandler();
    FTUninstallMachException();
    enableCrashMonitorLog(false);
    os_unfair_lock_unlock(&g_monitorsLock);
    FTLOG_DEBUG("All monitors have been disabled.");
}

void ftcm_handleException(FTThread thread,uintptr_t*backtrace,int count,const char *crashMessage){
    if (g_onExceptionEvent) {
        g_onExceptionEvent(thread,backtrace,count,crashMessage);
    }
    ftcm_disableAllMonitors();
}

void ftcm_setEventCallback(const FTCrashNotifyCallback onCrashNotify)
{
    g_onExceptionEvent = onCrashNotify;
}
bool ftcm_setCrashHandling(bool handling){
    bool handled = false;
    os_unfair_lock_lock(&g_monitorsLock);
    handled = g_crashIsHandling;
    if (g_crashIsHandling != handling) {
        g_crashIsHandling = handling;
    }
    os_unfair_lock_unlock(&g_monitorsLock);
    return handled;
}
