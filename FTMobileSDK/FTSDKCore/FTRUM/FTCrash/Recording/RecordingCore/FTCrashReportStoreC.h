//
//  FTCrashReportStoreC.h
//
//  Created by Karl Stenerud on 2012-02-05.
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

#ifndef FTCrashReportStoreC_h
#define FTCrashReportStoreC_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define FTCRASHCRS_MAX_PATH_LENGTH 500

/** The default name of a folder (inside the ftcrash install path) that is used for report store.
 */
#define FTCRASHCRS_DEFAULT_REPORTS_FOLDER "Reports"

/** Initialize the report store.
 *
 * @param appName The application's name.
 * @param reportsPath Full path to directory where the reports are to be stored
 * (path will be created if needed).
 */
void ftcrashcrs_initialize(const char *appName, const char *reportsPath);

/** Get the number of reports on disk.
 *
 * @return The number of reports on disk.
 */
int ftcrashcrs_getReportCount(void);

/** Get a list of IDs for all reports on disk.
 *
 * @param reportIDs An array big enough to hold all report IDs.
 * @param count How many reports the array can hold.
 *
 * @return The number of report IDs that were placed in the array.
 */
int ftcrashcrs_getReportIDs(int64_t *reportIDs, int count);

/** Read a report.
 *
 * @warning MEMORY MANAGEMENT WARNING: User is responsible for calling free() on the returned value.
 *
 * @param reportID The report's ID.
 *
 * @return The NULL terminated report, or NULL if not found.
 */
char *ftcrashcrs_readReport(int64_t reportID);

/** Read a report at a given path.
 * This is a convenience method for reading reports that are not in the standard reports directory.
 *
 * @warning MEMORY MANAGEMENT WARNING: User is responsible for calling free() on the returned value.
 *
 * @param path The full path to the report.
 *
 * @return The NULL terminated report, or NULL if not found.
 */
char *ftcrashcrs_readReportAtPath(const char *path);

/** Add a custom report to the store.
 *
 * @param report The report's contents (must be JSON encoded).
 * @param reportLength The length of the report in bytes.
 *
 * @return The new report's ID.
 */
int64_t ftcrashcrs_addUserReport(const char *report, int reportLength);

/** Delete all reports on disk.*/
void ftcrashcrs_deleteAllReports(void);

/** Delete report.
 *
 * @param reportID An ID of report to delete.
 */
void ftcrashcrs_deleteReportWithID(int64_t reportID);

/** Set the maximum number of reports allowed on disk before old ones get
 * deleted.
 *
 * @param maxReportCount The maximum number of reports.
 */
void ftcrashcrs_setMaxReportCount(int maxReportCount);


/** Get the next crash report to be generated.
 * Max length for paths is KSCRS_MAX_PATH_LENGTH
 *
 * @param crashReportPathBuffer Buffer to store the crash report path.
 * @param configuration The store configuretion (e.g. reports path, app name etc).
 *
 * @return The report ID of the next report.
 */
int64_t ftcrashcrs_getNextCrashReport(char *crashReportPathBuffer);

#ifdef __cplusplus
}
#endif
#endif /* FTCrashReportStoreC_h */
