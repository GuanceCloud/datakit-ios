//
//  FTCrashC.h
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

/* Primary C entry point into the crash reporting system.
 */

#ifndef FTCrashC_h
#define FTCrashC_h

#include <stdio.h>
#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "FTCrashMonitorType.h"
#include "FTCrashReportWriterCallbacks.h"


void ftcrash_install(const char *appName, const char *const installPath,FTCrashMonitorType monitors);

/** Set the user-supplied data in JSON format.
 *
 * @param userInfoJSON Pre-baked JSON containing user-supplied information.
 *                     NULL = delete.
 */
void ftcrash_setUserInfoJSON(const char *const userInfoJSON);

/** Get a copy of the user-supplied data in JSON format.
 *
 * @return A string containing the JSON user-supplied information,
 *         or NULL if no information is set.
 *         The caller is responsible for freeing the returned string.
 */
const char *ftcrash_getUserInfoJSON(void);

/** If true, introspect memory contents during a crash.
 * Any Objective-C objects or C strings near the stack pointer or referenced by
 * cpu registers or exceptions will be recorded in the crash report, along with
 * their contents.
 *
 * Default: false
 */
void ftcrash_setIntrospectMemory(bool introspectMemory);


/** Set the callback to invoke upon a crash.
 *
 * WARNING: Only call async-safe functions from this function! DO NOT call
 * Objective-C methods!!!
 *
 * @param onCrashNotify Function to call during a crash report to give the
 *                      callee an opportunity to add to the report.
 *                      NULL = ignore.
 *
 * Default: NULL
 */
void ftcrash_setCrashNotifyCallback(const FTCrashIsWritingReportCallback onCrashNotify);
/** Set the maximum number of reports allowed on disk before old ones get
 * deleted.
 *
 * @param maxReportCount The maximum number of reports.
 */
void ftcrash_setMaxReportCount(int maxReportCount);

#pragma mark-- Notifications --
/** Notify the crash reporter of FTCrash being added to Objective-C runtime system.
 */
void ftcrash_notifyObjCLoad(void);

/** Notify the crash reporter of the application active state.
 *
 * @param isActive true if the application is active, otherwise false.
 */
void ftcrash_notifyAppActive(bool isActive);

/** Notify the crash reporter of the application foreground/background state.
 *
 * @param isInForeground true if the application is in the foreground, false if
 *                 it is in the background.
 */
void ftcrash_notifyAppInForeground(bool isInForeground);

/** Notify the crash reporter that the application is terminating.
 */
void ftcrash_notifyAppTerminate(void);

/** Notify the crash reporter that the application has crashed.
 */
void ftcrash_notifyAppCrash(void);


#ifdef __cplusplus
}
#endif
#endif /* FTCrashC_h */
