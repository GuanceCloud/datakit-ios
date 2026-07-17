//
//  FTCrashMonitor_Signal.c
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

#include "FTCrashMonitor_Signal.h"

#include "FTCrashMonitorContext.h"
#include "FTCrashMonitorHelper.h"
#include "FTCrashMonitor_MachException.h"
#include "FTCrashID.h"
#include "FTCrashMachineContext.h"
#include "FTCrashSignalInfo.h"
#include "FTCrashStackCursor_MachineContext.h"
#include "FTSDKCompat.h"

#include "FTCrashLogger.h"

#if FT_HAS_SIGNAL

#include <errno.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static struct {
    _Atomic(FTCrashCM_InstalledState) installedState;
    atomic_bool isEnabled;
    bool sigtermMonitoringEnabled;

#if FT_HAS_SIGNAL_STACK
    /** Our custom signal stack. The signal handler will use this as its stack. */
    stack_t signalStack;
#endif

    /** Signal handlers that were installed before we installed ours. */
    struct sigaction *previousSignalHandlers;

    FTCrash_ExceptionHandlerCallbacks callbacks;
} g_state;

static bool isEnabled(void) { return g_state.isEnabled && g_state.installedState == FTCrashCM_Installed; }

// ============================================================================
#pragma mark - Private -
// ============================================================================

static void uninstall(void);
static bool shouldWriteReport(int sigNum) { return !(sigNum == SIGTERM && !g_state.sigtermMonitoringEnabled); }

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Our custom signal handler.
 * Restore the default signal handlers, record the signal information, and
 * write a crash report.
 * Once we're done, re-raise the signal and let the default handlers deal with
 * it.
 *
 * @param sigNum The signal that was raised.
 *
 * @param signalInfo Information about the signal.
 *
 * @param userContext Other contextual information.
 */
static void handleSignal(int sigNum, siginfo_t *signalInfo, void *userContext)
{
    FTLOG_DEBUG("Trapped signal %d", sigNum);
    if (isEnabled()) {
        thread_t thisThread = (thread_t)ftcrashthread_self();
        FTCrash_MonitorContext *crashContext = g_state.callbacks.notify(
            thisThread, (FTCrash_ExceptionHandlingRequirements) { .asyncSafety = true,
                                                                  .isFatal = true,
                                                                  .shouldRecordAllThreads = true,
                                                                  .shouldWriteReport = shouldWriteReport(sigNum) });
        if (crashContext->requirements.shouldExitImmediately) {
            goto exit_immediately;
        }

        FTLOG_DEBUG("Filling out context.");
        FTCrashStackCursor stackCursor = { 0 };
        FTCrashMachineContext machineContext = { 0 };
        ftcrashmc_getContextForSignal(userContext, &machineContext);
        ftcrashsc_initWithMachineContext(&stackCursor, FTCRASHSC_MAX_STACK_DEPTH, &machineContext);

        ftcrashcm_fillMonitorContext(crashContext, ftcrashcm_signal_getAPI());
        crashContext->offendingMachineContext = &machineContext;
        crashContext->registersAreValid = true;
        crashContext->faultAddress = (uintptr_t)signalInfo->si_addr;
        crashContext->signal.userContext = userContext;
        crashContext->signal.signum = signalInfo->si_signo;
        crashContext->signal.sigcode = signalInfo->si_code;
        crashContext->stackCursor = &stackCursor;

        g_state.callbacks.handle(crashContext);
    }

    FTLOG_DEBUG("Re-raising signal for regular handlers to catch.");
exit_immediately:
    uninstall();
    raise(sigNum);
}

// ============================================================================
#pragma mark - API -
// ============================================================================

static void install(void)
{
    FTCrashCM_InstalledState expectedState = FTCrashCM_NotInstalled;
    if (!atomic_compare_exchange_strong(&g_state.installedState, &expectedState, FTCrashCM_Installed)) {
        return;
    }

    FTLOG_DEBUG("Installing signal handler.");

#if FT_HAS_SIGNAL_STACK

    if (g_state.signalStack.ss_size == 0) {
        FTLOG_DEBUG("Allocating signal stack area.");
        g_state.signalStack.ss_size = SIGSTKSZ;
        g_state.signalStack.ss_sp = malloc(g_state.signalStack.ss_size);
    }

    FTLOG_DEBUG("Setting signal stack area.");
    if (sigaltstack(&g_state.signalStack, NULL) != 0) {
        FTLOG_ERROR("signalstack: %s", strerror(errno));
        goto failed;
    }
#endif

    const int *fatalSignals = ftcrashsignal_fatalSignals();
    int fatalSignalsCount = ftcrashsignal_numFatalSignals();

    if (g_state.previousSignalHandlers == NULL) {
        FTLOG_DEBUG("Allocating memory to store previous signal handlers.");
        g_state.previousSignalHandlers = malloc(sizeof(*g_state.previousSignalHandlers) * (unsigned)fatalSignalsCount);
    }

    struct sigaction action = { { 0 } };
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
#if defined(__LP64__)
    action.sa_flags |= SA_64REGSET;
#endif
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = &handleSignal;

    for (int i = 0; i < fatalSignalsCount; i++) {
        FTLOG_DEBUG("Assigning handler for signal %d", fatalSignals[i]);
        if (sigaction(fatalSignals[i], &action, &g_state.previousSignalHandlers[i]) != 0) {
            char sigNameBuff[30];
            const char *sigName = ftcrashsignal_signalName(fatalSignals[i]);
            if (sigName == NULL) {
                snprintf(sigNameBuff, sizeof(sigNameBuff), "%d", fatalSignals[i]);
                sigName = sigNameBuff;
            }
            FTLOG_ERROR("sigaction (%s): %s", sigName, strerror(errno));
            // Try to reverse the damage
            for (i--; i >= 0; i--) {
                sigaction(fatalSignals[i], &g_state.previousSignalHandlers[i], NULL);
            }
            goto failed;
        }
    }
    FTLOG_DEBUG("Signal handlers installed.");
    return;

failed:
    FTLOG_DEBUG("Failed to install signal handlers.");
    g_state.installedState = FTCrashCM_FailedInstall;
}

static void uninstall(void)
{
    FTCrashCM_InstalledState expectedState = FTCrashCM_Installed;
    if (!atomic_compare_exchange_strong(&g_state.installedState, &expectedState, FTCrashCM_Uninstalled)) {
        return;
    }
    FTLOG_DEBUG("Uninstalling signal handlers.");

    const int *fatalSignals = ftcrashsignal_fatalSignals();
    int fatalSignalsCount = ftcrashsignal_numFatalSignals();

    for (int i = 0; i < fatalSignalsCount; i++) {
        FTLOG_DEBUG("Restoring original handler for signal %d", fatalSignals[i]);
        sigaction(fatalSignals[i], &g_state.previousSignalHandlers[i], NULL);
    }

#if FT_HAS_SIGNAL_STACK
    g_state.signalStack = (stack_t) { 0 };
#endif
    FTLOG_DEBUG("Signal handlers uninstalled.");
}

static const char *monitorId(void) { return "Signal"; }

static FTCrashMonitorFlag monitorFlags(void) { return FTCrashMonitorFlagAsyncSafe; }

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

static void addContextualInfoToEvent(struct FTCrash_MonitorContext *eventContext)
{
    const char *machName = ftcrashcm_machexception_getAPI()->monitorId();

    if (!(strcmp(eventContext->monitorId, monitorId()) == 0 ||
          (machName && strcmp(eventContext->monitorId, machName) == 0))) {
        eventContext->signal.signum = SIGABRT;
    }
}

static void init(FTCrash_ExceptionHandlerCallbacks *callbacks) { g_state.callbacks = *callbacks; }

#endif /* FT_HAS_SIGNAL */

#if FT_HAS_SIGNAL
void ftcrashcm_signal_sigterm_setMonitoringEnabled(bool enabled) { g_state.sigtermMonitoringEnabled = enabled; }
#else
void ftcrashcm_signal_sigterm_setMonitoringEnabled(__unused bool enabled) {}
#endif

FTCrashMonitorAPI *ftcrashcm_signal_getAPI(void)
{
    static FTCrashMonitorAPI api = { 0 };
    if (ftcrashcma_initAPI(&api)) {
#if FT_HAS_SIGNAL
        api.init = init;
        api.monitorId = monitorId;
        api.monitorFlags = monitorFlags;
        api.setEnabled = setEnabled;
        api.isEnabled = isEnabled;
        api.addContextualInfoToEvent = addContextualInfoToEvent;
#endif
    }
    return &api;
}
