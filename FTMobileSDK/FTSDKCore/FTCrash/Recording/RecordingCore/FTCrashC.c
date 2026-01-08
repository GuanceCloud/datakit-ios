//
//  FTCrashC.c
//
//  Created by Karl Stenerud on 2012-01-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "FTCrashC.h"
#include "FTCrashBinaryImageCache.h"
#include "FTSDKCompat.h"
#include "FTCrashExceptionHandlingPlan.h"
#include "FTCrashMonitor.h"
#include "FTCrashMonitorContext.h"
#include "FTCrashMonitorType.h"
#include "FTCrashMonitor_AppState.h"
#include "FTCrashMonitor_CPPException.h"
#include "FTCrashMonitor_MachException.h"
#include "FTCrashMonitor_NSException.h"
#include "FTCrashMonitor_Signal.h"
#include "FTCrashMonitor_System.h"
#include "FTCrashReportC.h"
#include "FTCrashFileUtils.h"
#include "FTCrashObjC.h"
#include "FTCrashString.h"
#include "FTCrashThreadCache.h"
#include "FTCrashReportStoreC.h"
#include "FTCrashDynamicLinker.h"

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "FTCrashLogger.h"


typedef enum {
    FTCrashApplicationStateNone,
    FTCrashApplicationStateDidBecomeActive,
    FTCrashApplicationStateWillResignActiveActive,
    FTCrashApplicationStateDidEnterBackground,
    FTCrashApplicationStateWillEnterForeground,
    FTCrashApplicationStateWillTerminate
} FTCrashApplicationState;

static volatile bool g_installed = 0;
static bool g_shouldAddConsoleLogToReport = false;
static bool g_shouldPrintPreviousLog = false;
static char g_consoleLogPath[FTCRASHFU_MAX_PATH_LENGTH];
static FTCrashCMonitorType g_monitoring = FTCrashCMonitorTypeSignal | FTCrashCMonitorTypeCPPException | FTCrashCMonitorTypeNSException | FTCrashCMonitorTypeSystem;
static char g_lastCrashReportFilePath[FTCRASHFU_MAX_PATH_LENGTH];

static FTCrashWillWriteReportCallback g_willWriteReportCallback;
static FTCrashIsWritingReportCallback g_isWritingReportCallback;
static FTCrashDidWriteReportCallback g_didWriteReportCallback;
static FTCrashApplicationState g_lastApplicationState = FTCrashApplicationStateNone;


static const struct FTCrashMonitorMapping {
    FTCrashCMonitorType type;
    FTCrashMonitorAPI *(*getAPI)(void);
} g_monitorMappings[] = { { FTCrashCMonitorTypeMachException, ftcrashcm_machexception_getAPI },
    { FTCrashCMonitorTypeSignal, ftcrashcm_signal_getAPI },
    { FTCrashCMonitorTypeCPPException, ftcrashcm_cppexception_getAPI },
    { FTCrashCMonitorTypeNSException, ftcrashcm_nsexception_getAPI },
    { FTCrashCMonitorTypeSystem, ftcrashcm_system_getAPI },
    { FTCrashCMonitorTypeApplicationState, ftcrashcm_appstate_getAPI}
};

static const size_t g_monitorMappingCount = sizeof(g_monitorMappings) / sizeof(g_monitorMappings[0]);

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Called when a crash occurs.
 *
 * This function gets passed as a callback to a crash handler.
 */
static void onExceptionEvent(struct FTCrash_MonitorContext *monitorContext)
{
    // Check if the user wants to modify the plan for this crash.
    if (g_willWriteReportCallback) {
        FTCrash_ExceptionHandlingPlan plan = ftcrashexc_monitorContextToPlan(monitorContext);
        g_willWriteReportCallback(&plan, monitorContext);
        ftcrashexc_modifyMonitorContextUsingPlan(monitorContext, &plan);
    }

    // If we shouldn't write a report, then there's nothing left to do here.
    if (!monitorContext->requirements.shouldWriteReport) {
        return;
    }

    if (monitorContext->currentSnapshotUserReported == false) {
        FTLOG_DEBUG("Updating application state to note crash.");
        ftcrashstate_notifyAppCrash();
    }
    monitorContext->consoleLogPath = g_shouldAddConsoleLogToReport ? g_consoleLogPath : NULL;

    if (monitorContext->requirements.crashedDuringExceptionHandling) {
        ftcrashreport_writeRecrashReport(monitorContext, g_lastCrashReportFilePath);
    } else if (monitorContext->reportPath) {
        ftcrashreport_writeStandardReport(monitorContext, monitorContext->reportPath);
    } else {
        char crashReportFilePath[FTCRASHFU_MAX_PATH_LENGTH];
        int64_t reportID = ftcrashcrs_getNextCrashReport(crashReportFilePath);
        strncpy(g_lastCrashReportFilePath, crashReportFilePath, sizeof(g_lastCrashReportFilePath));
        ftcrashreport_writeStandardReport(monitorContext, crashReportFilePath);

        if (g_didWriteReportCallback != NULL) {
            FTCrash_ExceptionHandlingPlan plan = ftcrashexc_monitorContextToPlan(monitorContext);
            g_didWriteReportCallback(&plan, reportID);
        }
    }
}

static void setMonitors(FTCrashCMonitorType monitorTypes)
{
    g_monitoring = monitorTypes;

    for (size_t i = 0; i < g_monitorMappingCount; i++) {
        FTCrashMonitorAPI *api = g_monitorMappings[i].getAPI();
        if (api != NULL) {
            if (monitorTypes & g_monitorMappings[i].type) {
                ftcrashcm_addMonitor(api);
            } else {
                ftcrashcm_removeMonitor(api);
            }
        }
    }
}

// ============================================================================
#pragma mark - API -
// ============================================================================

void ftcrash_install(const char *appName, const char *const installPath,FTCrashCMonitorType monitors){
    //enableCrashMonitorLog(false);
    if (g_installed) {
        FTLOG_DEBUG("Crash reporter already installed.");
        return;
    }
    if (appName == NULL || installPath == NULL) {
        FTLOG_ERROR("Invalid parameters: appName or installPath is NULL.");
        return;
    }
    ftcrashreport_setIsWritingReportCallback(g_isWritingReportCallback);
    char path[FTCRASHFU_MAX_PATH_LENGTH];
    snprintf(path, sizeof(path), "%s/Reports", installPath);
    ftcrashfu_makePath(path);
    ftcrashcrs_initialize(appName, path);
    
    snprintf(path, sizeof(path), "%s/Data", installPath);
    ftcrashfu_makePath(path);
    snprintf(path, sizeof(path), "%s/Data/CrashState.json", installPath);
    ftcrashstate_initialize(path);

    ftcrashtc_init(60);
        
    ftcrashcm_setEventCallback(onExceptionEvent);
    setMonitors(monitors);
    ftcrashcm_activateMonitors();
    
    g_installed = true;
}
void ftcrash_setWillWriteCrashNotifyCallback(const FTCrashWillWriteReportCallback onCrashNotify){
    g_willWriteReportCallback = onCrashNotify;
}
void ftcrash_setCrashNotifyCallback(const FTCrashIsWritingReportCallback onCrashNotify){
    g_isWritingReportCallback = onCrashNotify;
}

void ftcrash_setUserInfoJSON(const char *const userInfoJSON) { ftcrashreport_setUserInfoJSON(userInfoJSON); }

const char *ftcrash_getUserInfoJSON(void) { return ftcrashreport_getUserInfoJSON(); }

void ftcrash_setIntrospectMemory(bool introspectMemory)
{
    ftcrashreport_setIntrospectMemory(introspectMemory);
}
void ftcrash_setMaxReportCount(int maxReportCount){
    ftcrashcrs_setMaxReportCount(maxReportCount);
}
void ftcrash_notifyObjCLoad(void) { ftcrashstate_notifyObjCLoad(); }

void ftcrash_notifyAppActive(bool isActive){
    ftcrashstate_notifyAppActive(isActive);
}

void ftcrash_notifyAppInForeground(bool isInForeground){
    ftcrashstate_notifyAppInForeground(isInForeground);
}


void ftcrash_notifyAppTerminate(void){
    ftcrashstate_notifyAppTerminate();
}

void ftcrash_notifyAppCrash(void) { ftcrashstate_notifyAppCrash(); }
