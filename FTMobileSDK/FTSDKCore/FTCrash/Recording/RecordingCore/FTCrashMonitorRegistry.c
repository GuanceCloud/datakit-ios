//
//  FTCrashMonitorRegistry.c
//
//  Created by Karl Stenerud on 2025-08-09.
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

#include "FTCrashMonitorRegistry.h"

#include <stdatomic.h>

#include "FTCrashDebug.h"

#include "FTCrashLogger.h"

bool ftcrashcmr_addMonitor(FTCrashMonitorAPIList *monitorList, const FTCrashMonitorAPI *api)
{
    if (api == NULL) {
        return false;
    }

    bool added = false;
    for (size_t i = 0; i < FTCRASH_MONITOR_API_COUNT; i++) {
        if (atomic_load(monitorList->apis + i) == api) {
            FTLOG_DEBUG("Monitor %s already exists. Skipping addition.", api->monitorId());
            return false;
        }

        // Make sure we're swapping from null to our API, and not something else that got swapped in meanwhile.
        const FTCrashMonitorAPI *expectedAPI = NULL;
        if (atomic_compare_exchange_strong(monitorList->apis + i, &expectedAPI, api)) {
            added = true;
            break;
        }
    }

    if (!added) {
        // This should never happen, but never say never!
        FTLOG_ERROR("Failed to add monitor API \"%s\"", api->monitorId());
        return false;
    }

    // Check for and remove duplicates in case another thread also just added the same API.
    bool found = false;
    for (size_t i = 0; i < FTCRASH_MONITOR_API_COUNT; i++) {
        if (atomic_load(monitorList->apis + i) == api) {
            if (!found) {
                // Leave the first copy alone.
                found = true;
            } else {
                // Make sure we're swapping from our API to null, and not something else that got swapped in meanwhile.
                const FTCrashMonitorAPI *expectedAPI = api;
                atomic_compare_exchange_strong(monitorList->apis + i, &expectedAPI, NULL);
            }
        }
    }

    FTLOG_DEBUG("Monitor %s injected.", api->monitorId());
    return true;
}

void ftcrashcmr_removeMonitor(FTCrashMonitorAPIList *monitorList, const FTCrashMonitorAPI *api)
{
    if (api == NULL) {
        return;
    }

    for (size_t i = 0; i < FTCRASH_MONITOR_API_COUNT; i++) {
        // Make sure we're swapping from our API to null, and not something else that got swapped in meanwhile.
        const FTCrashMonitorAPI *expectedAPI = api;
        if (atomic_compare_exchange_strong(monitorList->apis + i, &expectedAPI, NULL)) {
            api->setEnabled(false);
        }
    }
}

bool ftcrashcmr_activateMonitors(FTCrashMonitorAPIList *monitorList)
{
    // Check for debugger and async safety
    bool isDebuggerUnsafe = ftcrashdebug_isBeingTraced();

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

    // Enable or disable monitors
    bool anyMonitorActive = false;
    for (size_t i = 0; i < FTCRASH_MONITOR_API_COUNT; i++) {
        const FTCrashMonitorAPI *api = monitorList->apis[i];
        if (api == NULL) {
            // Found a hole. Skip it.
            continue;
        }
        FTCrashMonitorFlag flags = api->monitorFlags();
        bool shouldEnable = true;

        if (isDebuggerUnsafe && (flags & FTCrashMonitorFlagDebuggerUnsafe)) {
            shouldEnable = false;
        }

        api->setEnabled(shouldEnable);
        bool isEnabled = api->isEnabled();
        anyMonitorActive |= isEnabled;
        FTLOG_DEBUG("Monitor %s is now %sabled.", api->monitorId(), isEnabled ? "en" : "dis");
    }

    for (size_t i = 0; i < FTCRASH_MONITOR_API_COUNT; i++) {
        const FTCrashMonitorAPI *api = monitorList->apis[i];
        if (api != NULL && api->isEnabled()) {
            api->notifyPostSystemEnable();
        }
    }

    return anyMonitorActive;
}

void ftcrashcmr_disableAllMonitors(FTCrashMonitorAPIList *monitorList)
{
    for (size_t i = 0; i < FTCRASH_MONITOR_API_COUNT; i++) {
        const FTCrashMonitorAPI *api = monitorList->apis[i];
        if (api != NULL) {
            api->setEnabled(false);
        }
    }
    FTLOG_DEBUG("All monitors have been disabled.");
}

void ftcrashcmr_addContextualInfoToEvent(FTCrashMonitorAPIList *monitorList, struct FTCrash_MonitorContext *ctx)
{
    for (size_t i = 0; i < FTCRASH_MONITOR_API_COUNT; i++) {
        const FTCrashMonitorAPI *api = monitorList->apis[i];
        if (api != NULL && api->isEnabled()) {
            api->addContextualInfoToEvent(ctx);
        }
    }
}

