//
//  FTCrashMonitor_NSException.m
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
#import "FTCrashMonitor_NSException.h"
#import "FTCrashCompilerDefines.h"
#import "FTCrashMonitorContext.h"
#import "FTCrashMonitorHelper.h"
#import "FTCrashID.h"
#import "FTCrashStackCursor_Backtrace.h"
#import "FTCrashStackCursor_SelfThread.h"
#import "FTCrashThread.h"

#import <Foundation/Foundation.h>
#import <stdatomic.h>

#import "FTCrashLogger.h"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static struct {
    _Atomic(FTCrashCM_InstalledState) installedState;
    atomic_bool isEnabled;

    /** The exception handler that was in place before we installed ours. */
    NSUncaughtExceptionHandler *previousUncaughtExceptionHandler;

    FTCrash_ExceptionHandlerCallbacks callbacks;

} g_state;

static bool isEnabled(void) { return g_state.isEnabled && g_state.installedState == FTCrashCM_Installed; }

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

static FTCRASH_NOINLINE void initStackCursor(FTCrashStackCursor *cursor, NSException *exception, uintptr_t *callstack,
                                        BOOL isUserReported) FTCRASH_KEEP_FUNCTION_IN_STACKTRACE
{
    // Use stacktrace from NSException if present,
    // otherwise use current thread (can happen for user-reported exceptions).
    NSArray *addresses = [exception callStackReturnAddresses];
    NSUInteger numFrames = addresses.count;
    if (numFrames != 0) {
        callstack = malloc(numFrames * sizeof(*callstack));
        for (NSUInteger i = 0; i < numFrames; i++) {
            callstack[i] = (uintptr_t)[addresses[i] unsignedLongLongValue];
        }
        ftcrashsc_initWithBacktrace(cursor, callstack, (int)numFrames, 0);
    } else {
        /* Skip frames for user-reported:
         * 1. `initStackCursor`
         * 2. `handleException`
         * 3. `customNSExceptionReporter`
         * 4. `+[FTCrash reportNSException:logAllThreads:]`
         *
         * Skip frames for caught exceptions (unlikely scenario):
         * 1. `initStackCursor`
         * 2. `handleException`
         * 3. `handleUncaughtException`
         */
        int const skipFrames = isUserReported ? 4 : 3;
        ftcrashsc_initSelfThread(cursor, skipFrames);
    }
    FTCRASH_THWART_TAIL_CALL_OPTIMISATION
}

/** Our custom excepetion handler.
 * Fetch the stack trace from the exception and write a report.
 *
 * @param exception The exception that was raised.
 */
static FTCRASH_NOINLINE void handleException(NSException *exception, BOOL isUserReported,
                                        BOOL logAllThreads) FTCRASH_KEEP_FUNCTION_IN_STACKTRACE
{
    FTLOG_DEBUG("Trapped exception %@", exception);
    if (isEnabled()) {
        FTLOG_DEBUG("Trapped exception start");
        // Gather this info before we require async-safety:
        const char *exceptionName = exception.name.UTF8String;
        const char *exceptionReason = exception.reason.UTF8String;
        NS_VALID_UNTIL_END_OF_SCOPE NSString *userInfoString =
            exception.userInfo != nil ? [NSString stringWithFormat:@"%@", exception.userInfo] : nil;
        const char *userInfo = userInfoString.UTF8String;
//        FTLOG_DEBUG("Filling out context.");
        thread_t thisThread = (thread_t)ftcrashthread_self();
        FTCrashMachineContext machineContext = { 0 };
        ftcrashmc_getContextForThread(thisThread, &machineContext, true);
        FTCrashStackCursor cursor;
        uintptr_t *callstack = NULL;
        initStackCursor(&cursor, exception, callstack, isUserReported);

        // Now start exception handling
        FTCrash_MonitorContext *crashContext = g_state.callbacks.notify(
            thisThread, (FTCrash_ExceptionHandlingRequirements) { .asyncSafety = false,
                                                                  // User-reported exceptions are not considered fatal.
                                                                  .isFatal = !isUserReported,
                                                                  .shouldRecordAllThreads = logAllThreads != NO,
                                                                  .shouldWriteReport = true });
        if (crashContext->requirements.shouldExitImmediately) {
            goto exit_immediately;
        }

        ftcrashcm_fillMonitorContext(crashContext, ftcrashcm_nsexception_getAPI());
        crashContext->offendingMachineContext = &machineContext;
        crashContext->registersAreValid = false;
        crashContext->NSException.name = exceptionName;
        crashContext->NSException.userInfo = userInfo;
        crashContext->exceptionName = exceptionName;
        crashContext->crashReason = exceptionReason;
        crashContext->stackCursor = &cursor;
        crashContext->currentSnapshotUserReported = isUserReported;

//        FTLOG_DEBUG(@"Calling main crash handler.");
        g_state.callbacks.handle(crashContext);
        FTLOG_DEBUG("Trapped exception end");
    exit_immediately:
        free(callstack);
    }
    if (!isUserReported && g_state.previousUncaughtExceptionHandler != NULL) {
//        FTLOG_DEBUG(@"Calling original exception handler.");
        g_state.previousUncaughtExceptionHandler(exception);
    }
    FTCRASH_THWART_TAIL_CALL_OPTIMISATION
}

//static void customNSExceptionReporter(NSException *exception, BOOL logAllThreads) FTCRASH_KEEP_FUNCTION_IN_STACKTRACE
//{
//    handleException(exception, YES, logAllThreads);
//    FTCRASH_THWART_TAIL_CALL_OPTIMISATION
//}

static void handleUncaughtException(NSException *exception) FTCRASH_KEEP_FUNCTION_IN_STACKTRACE
{
    handleException(exception, NO, YES);
    FTCRASH_THWART_TAIL_CALL_OPTIMISATION
}

static void install(void)
{
    FTCrashCM_InstalledState expectedState = FTCrashCM_NotInstalled;
    if (!atomic_compare_exchange_strong(&g_state.installedState, &expectedState, FTCrashCM_Installed)) {
        return;
    }

//    FTLOG_DEBUG(@"Backing up original handler.");
    g_state.previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
//    FTLOG_DEBUG(@"Setting new handler.");
    NSSetUncaughtExceptionHandler(&handleUncaughtException);
}

// ============================================================================
#pragma mark - API -
// ============================================================================

static void setEnabled(bool enabled)
{
    bool expectedState = !enabled;
    if (!atomic_compare_exchange_strong(&g_state.isEnabled, &expectedState, enabled)) {
        // We were already in the expected state
        return;
    }

    if (enabled) {
        install();
    }
}

static const char *monitorId(void) { return "NSException"; }

static FTCrashMonitorFlag monitorFlags(void) { return FTCrashMonitorFlagNone; }

static void init(FTCrash_ExceptionHandlerCallbacks *callbacks) { g_state.callbacks = *callbacks; }

FTCrashMonitorAPI *ftcrashcm_nsexception_getAPI(void)
{
    static FTCrashMonitorAPI api = { 0 };
    if (ftcrashcma_initAPI(&api)) {
        api.init = init;
        api.monitorId = monitorId;
        api.monitorFlags = monitorFlags;
        api.setEnabled = setEnabled;
        api.isEnabled = isEnabled;
    }
    return &api;
}
