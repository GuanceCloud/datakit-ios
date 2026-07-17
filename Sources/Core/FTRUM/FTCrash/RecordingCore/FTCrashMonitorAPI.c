//
//  FTCrashMonitorAPI.c
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

#include "FTCrashMonitorAPI.h"

static void default_init(__unused FTCrash_ExceptionHandlerCallbacks *callbacks) {}
static FTCrashMonitorFlag default_monitorFlags(void) { return 0; }
static const char *default_monitorId(void) { return "unset"; }
static void default_setEnabled(__unused bool isEnabled) {}
static bool default_isEnabled(void) { return false; }
static void default_addContextualInfoToEvent(__unused struct FTCrash_MonitorContext *eventContext) {}
static void default_notifyPostSystemEnable(void) {}
static FTCrashMonitorAPI g_defaultAPI = {
    .init = default_init,
    .monitorId = default_monitorId,
    .monitorFlags = default_monitorFlags,
    .setEnabled = default_setEnabled,
    .isEnabled = default_isEnabled,
    .addContextualInfoToEvent = default_addContextualInfoToEvent,
    .notifyPostSystemEnable = default_notifyPostSystemEnable,
};

bool ftcrashcma_initAPI(FTCrashMonitorAPI *api)
{
    if (api != NULL && api->init == NULL) {
        *api = g_defaultAPI;
        return true;
    }
    return false;
}
