//
//  FTCrashMonitor_AppState.c
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

#include "FTCrashMonitor_AppState.h"
#include "FTEarlyCrash.h"

#include "FTCrashMonitorContext.h"
#include "FTCrashFileUtils.h"
#include "FTCrashJSONCodec.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include "FTCrashLogger.h"

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define kFormatVersion 1

#define kKeyFormatVersion "version"
#define kKeyCrashedLastLaunch "crashedLastLaunch"
#define kKeyPreviousEarlyCrash "previousEarlyCrash"
#define kKeyEarlyCrashDurationNS "earlyCrashDurationNS"
#define kKeyCrashedLastDate "crashedLastDate"
#define kKeyDurationFromCrashStateInitToLastCrash "durationFromCrashStateInitToLastCrash"
#define kKeyActiveDurationSinceLastCrash "activeDurationSinceLastCrash"
#define kKeyBackgroundDurationSinceLastCrash "backgroundDurationSinceLastCrash"
#define kKeyLaunchesSinceLastCrash "launchesSinceLastCrash"
#define kKeySessionsSinceLastCrash "sessionsSinceLastCrash"
#define kKeySessionsSinceLaunch "sessionsSinceLaunch"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Location where stat file is stored. */
static const char *g_stateFilePath;

/** Current state. */
static FTCrash_AppState g_state;

static atomic_bool g_isEnabled = false;
_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2, "Early crash capture requires lock-free atomics");
static atomic_ullong g_earlyCrashDurationNS = UINT64_MAX;
static bool g_consumedHistory;
typedef struct {
    FTCrash_AppState *state;
    bool sawVersion;
} StateDecodeContext;

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

static int onBooleanElement(const char *const name, const bool value, void *const userData)
{
    if (name == NULL) return FTCRASHJSON_ERROR_INVALID_DATA;
    FTCrash_AppState *state = ((StateDecodeContext *)userData)->state;

    if (strcmp(name, kKeyCrashedLastLaunch) == 0) {
        state->crashedLastLaunch = value;
    } else if (strcmp(name, kKeyPreviousEarlyCrash) == 0) {
        state->previousEarlyCrash = value;
    } else if (strcmp(name, kKeyEarlyCrashDurationNS) == 0) {
        state->previousEarlyCrashDurationNS = UINT64_MAX;
    }

    return FTCRASHJSON_OK;
}

static int onFloatingPointElement(const char *const name, const double value, void *const userData)
{
    if (name == NULL) return FTCRASHJSON_ERROR_INVALID_DATA;
    FTCrash_AppState *state = ((StateDecodeContext *)userData)->state;

    if (strcmp(name, kKeyEarlyCrashDurationNS) == 0) {
        state->previousEarlyCrashDurationNS = UINT64_MAX;
        return FTCRASHJSON_OK;
    }
    if (strcmp(name, kKeyPreviousEarlyCrash) == 0) {
        state->previousEarlyCrash = false;
        return FTCRASHJSON_OK;
    }
    if (strcmp(name, kKeyActiveDurationSinceLastCrash) == 0) {
        state->activeDurationSinceLastCrash = value;
    }
    if (strcmp(name, kKeyBackgroundDurationSinceLastCrash) == 0) {
        state->backgroundDurationSinceLastCrash = value;
    }

    return FTCRASHJSON_OK;
}

static int onIntegerElement(const char *const name, const int64_t value, void *const userData)
{
    if (name == NULL) return FTCRASHJSON_ERROR_INVALID_DATA;
    FTCrash_AppState *state = ((StateDecodeContext *)userData)->state;

    if (strcmp(name, kKeyEarlyCrashDurationNS) == 0) {
        state->previousEarlyCrashDurationNS = value >= 0 ? (uint64_t)value : UINT64_MAX;
        return FTCRASHJSON_OK;
    }
    if (strcmp(name, kKeyFormatVersion) == 0) {
        ((StateDecodeContext *)userData)->sawVersion = value == kFormatVersion;
        if (value != kFormatVersion) {
            FTLOG_ERROR("Expected version 1 but got %" PRId64, value);
            return FTCRASHJSON_ERROR_INVALID_DATA;
        }
    } else if (strcmp(name, kKeyLaunchesSinceLastCrash) == 0) {
        state->launchesSinceLastCrash = (int)value;
    } else if (strcmp(name, kKeySessionsSinceLastCrash) == 0) {
        state->sessionsSinceLastCrash = (int)value;
    } else if (strcmp(name, kKeyCrashedLastDate) == 0) {
        state->crashedLastTimestamp = (int)value;
    }

    // FP value might have been written as a whole number.
    return onFloatingPointElement(name, (double)value, userData);
}

static int onUnsignedIntegerElement(const char *const name, const uint64_t value, void *const userData)
{
    if (name == NULL) return FTCRASHJSON_ERROR_INVALID_DATA;
    FTCrash_AppState *state = ((StateDecodeContext *)userData)->state;

    if (strcmp(name, kKeyEarlyCrashDurationNS) == 0) {
        state->previousEarlyCrashDurationNS = value;
        return FTCRASHJSON_OK;
    }
    if (strcmp(name, kKeyFormatVersion) == 0) {
        ((StateDecodeContext *)userData)->sawVersion = value == kFormatVersion;
        if (value != kFormatVersion) {
            FTLOG_ERROR("Expected version 1 but got %" PRIu64, value);
            return FTCRASHJSON_ERROR_INVALID_DATA;
        }
    } else if (strcmp(name, kKeyLaunchesSinceLastCrash) == 0) {
        if (value <= INT_MAX) {
            state->launchesSinceLastCrash = (int)value;
        } else {
            FTLOG_ERROR("launchesSinceLastCrash (%" PRIu64 ") exceeds INT_MAX", value);
            return FTCRASHJSON_ERROR_INVALID_DATA;
        }
    } else if (strcmp(name, kKeySessionsSinceLastCrash) == 0) {
        if (value <= INT_MAX) {
            state->sessionsSinceLastCrash = (int)value;
        } else {
            FTLOG_ERROR("sessionsSinceLastCrash (%" PRIu64 ") exceeds INT_MAX", value);
            return FTCRASHJSON_ERROR_INVALID_DATA;
        }
    }else if (strcmp(name, kKeyCrashedLastDate) == 0) {
        if (value <= INT_MAX) {
            state->crashedLastTimestamp = (int)value;
        } else {
            FTLOG_ERROR("crashedLastDate (%" PRIu64 ") exceeds INT_MAX", value);
            return FTCRASHJSON_ERROR_INVALID_DATA;
        }
    }

    // For other fields or if the value doesn't fit in an int, treat it as a floating point
    return onFloatingPointElement(name, (double)value, userData);
}

static int onNullElement(const char *const name, void *const userData) {
    if (name == NULL) return FTCRASHJSON_OK;
    FTCrash_AppState *state = ((StateDecodeContext *)userData)->state;
    if (strcmp(name, kKeyEarlyCrashDurationNS) == 0) state->previousEarlyCrashDurationNS = UINT64_MAX;
    if (strcmp(name, kKeyPreviousEarlyCrash) == 0) state->previousEarlyCrash = false;
    return FTCRASHJSON_OK;
}

static int onStringElement(__unused const char *const name, __unused const char *const value,
                           __unused void *const userData)
{
    return onNullElement(name, userData);
}

static int onBeginObject(__unused const char *const name, __unused void *const userData) { return FTCRASHJSON_OK; }

static int onBeginArray(__unused const char *const name, __unused void *const userData) { return FTCRASHJSON_OK; }

static int onEndContainer(__unused void *const userData) { return FTCRASHJSON_OK; }

static int onEndData(__unused void *const userData) { return FTCRASHJSON_OK; }

/** Callback for adding JSON data.
 */
static int addJSONData(const char *const data, const int length, void *const userData)
{
    const int fd = *((int *)userData);
    const bool success = ftcrashfu_writeBytesToFD(fd, data, length);
    return success ? FTCRASHJSON_OK : FTCRASHJSON_ERROR_CANNOT_ADD_DATA;
}
// ============================================================================
#pragma mark - Utility -
// ============================================================================

static double getCurrentTime(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec + (double)tv.tv_usec / 1000000.0;
}

static double timeSince(double timeInSeconds) { return getCurrentTime() - timeInSeconds; }

/** Load the persistent state portion of a crash context.
 *
 * @param path The path to the file to read.
 *
 * @return true if the operation was successful.
 */
static bool loadState(const char *const path, FTCrash_AppState *const state)
{
    // Stop if the file doesn't exist.
    // This is expected on the first run of the app.
    const int fd = open(path, O_RDONLY);
    if (fd < 0) {
        return false;
    }
    close(fd);

    char *data;
    int length;
    if (!ftcrashfu_readEntireFile(path, &data, &length, 50000)) {
        FTLOG_ERROR("%s: Could not load file", path);
        return false;
    }

    // A CrashState document is an object. Reject corrupt scalar/array roots
    // before dispatching callbacks that expect named object fields.
    int first = 0;
    while (first < length && (data[first] == ' ' || data[first] == '\t' ||
                             data[first] == '\r' || data[first] == '\n')) first++;
    if (first == length || data[first] != '{') {
        free(data);
        return false;
    }

    FTCrashJSONDecodeCallbacks callbacks;
    callbacks.onBeginArray = onBeginArray;
    callbacks.onBeginObject = onBeginObject;
    callbacks.onBooleanElement = onBooleanElement;
    callbacks.onEndContainer = onEndContainer;
    callbacks.onEndData = onEndData;
    callbacks.onFloatingPointElement = onFloatingPointElement;
    callbacks.onIntegerElement = onIntegerElement;
    callbacks.onUnsignedIntegerElement = onUnsignedIntegerElement;
    callbacks.onNullElement = onNullElement;
    callbacks.onStringElement = onStringElement;

    int errorOffset = 0;

    char stringBuffer[1000];
    StateDecodeContext decode = {.state = state};
    const int result =
        ftcrashjson_decode(data, (int)length, stringBuffer, sizeof(stringBuffer), &callbacks, &decode, &errorOffset);
    free(data);
    if (result != FTCRASHJSON_OK) {
        FTLOG_ERROR("%s, offset %d: %s", path, errorOffset, ftcrashjson_stringForError(result));
        return false;
    }
    state->previousEarlyCrash = decode.sawVersion && state->previousEarlyCrash &&
        state->previousEarlyCrashDurationNS <= UINT64_C(5000000000);
    return true;
}
/** Save the persistent state portion of a crash context.
 *
 * @param path The path to the file to create.
 *
 * @return true if the operation was successful.
 */
static bool saveState(const char *const path)
{
    const uint64_t earlyDuration = atomic_load(&g_earlyCrashDurationNS);
    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        FTLOG_ERROR("Could not open file %s for writing: %s", path, strerror(errno));
        return false;
    }

    FTCrashJSONEncodeContext JSONContext;
    ftcrashjson_beginEncode(&JSONContext, true, addJSONData, &fd);

    int result;
    if ((result = ftcrashjson_beginObject(&JSONContext, NULL)) != FTCRASHJSON_OK) {
        goto done;
    }
    if ((result = ftcrashjson_addIntegerElement(&JSONContext, kKeyFormatVersion, kFormatVersion)) != FTCRASHJSON_OK) {
        goto done;
    }
    if ((result = ftcrashjson_addBooleanElement(&JSONContext, kKeyPreviousEarlyCrash,
                                               earlyDuration <= UINT64_C(5000000000))) != FTCRASHJSON_OK) goto done;
    if ((result = ftcrashjson_addUIntegerElement(&JSONContext, kKeyEarlyCrashDurationNS,
                                                earlyDuration)) != FTCRASHJSON_OK) goto done;
    // Record this launch crashed state into "crashed last launch" field.
    if ((result = ftcrashjson_addBooleanElement(&JSONContext, kKeyCrashedLastLaunch, g_state.crashedThisLaunch)) !=
        FTCRASHJSON_OK) {
        goto done;
    }
    if ((result = ftcrashjson_addIntegerElement(&JSONContext, kKeyCrashedLastDate, g_state.crashedThisTimestamp)) !=
        FTCRASHJSON_OK) {
        goto done;
    }
    if ((result = ftcrashjson_addFloatingPointElement(&JSONContext, kKeyActiveDurationSinceLastCrash,
                                                 g_state.activeDurationSinceLastCrash)) != FTCRASHJSON_OK) {
        goto done;
    }
    if ((result = ftcrashjson_addFloatingPointElement(&JSONContext, kKeyBackgroundDurationSinceLastCrash,
                                                 g_state.backgroundDurationSinceLastCrash)) != FTCRASHJSON_OK) {
        goto done;
    }
    if ((result = ftcrashjson_addIntegerElement(&JSONContext, kKeyLaunchesSinceLastCrash, g_state.launchesSinceLastCrash)) !=
        FTCRASHJSON_OK) {
        goto done;
    }
    if ((result = ftcrashjson_addIntegerElement(&JSONContext, kKeySessionsSinceLastCrash, g_state.sessionsSinceLastCrash)) !=
        FTCRASHJSON_OK) {
        goto done;
    }
    result = ftcrashjson_endEncode(&JSONContext);

done:
    close(fd);
    if (result != FTCRASHJSON_OK) {
        FTLOG_ERROR("%s: %s", path, ftcrashjson_stringForError(result));
        return false;
    }
    // A pre-crash ordinary save may resume after the crash writer. Reconcile
    // that one-way transition so its stale snapshot cannot overwrite the fact.
    // Duration changes at most once per process, bounding this to one retry.
    if (earlyDuration == UINT64_MAX && atomic_load(&g_earlyCrashDurationNS) != UINT64_MAX)
        return saveState(path);
    return true;
}

static void updateAppState(void)
{
    const double duration = timeSince(g_state.appStateTransitionTime);
    g_state.appStateTransitionTime = getCurrentTime();

    if (g_state.applicationIsActive) {
        FTLOG_ERROR("Updating activeDurationSinceLaunch: %f and activeDurationSinceLastCrash: %f with duration: %f",
                    g_state.activeDurationSinceLaunch, g_state.activeDurationSinceLastCrash, duration);
        g_state.activeDurationSinceLaunch += duration;
        g_state.activeDurationSinceLastCrash += duration;
    } else if (!g_state.applicationIsInForeground) {
        FTLOG_ERROR(
            "Updating backgroundDurationSinceLaunch: %f and backgroundDurationSinceLastCrash: %f with duration: %f",
            g_state.backgroundDurationSinceLaunch, g_state.backgroundDurationSinceLastCrash, duration);
        g_state.backgroundDurationSinceLaunch += duration;
        g_state.backgroundDurationSinceLastCrash += duration;
    }
}
// ============================================================================
#pragma mark - API -
// ============================================================================

bool ftcrashstate_readPersistedState(const char *path, FTCrash_AppState *state)
{
    if (path == NULL || state == NULL) return false;
    FTCrash_AppState snapshot = {.previousEarlyCrashDurationNS = UINT64_MAX};
    if (!loadState(path, &snapshot)) return false;
    *state = snapshot;
    return true;
}

void ftcrashstate_initialize(const char *const stateFilePath)
{
    // Never reread or consume this launch's new fact after SDK reinitialization.
    if (g_stateFilePath != NULL || stateFilePath == NULL) return;
    g_stateFilePath = strdup(stateFilePath);
    FTCrash_AppState snapshot;
    if (ftcrashstate_readPersistedState(g_stateFilePath, &snapshot)) {
        g_state.activeDurationSinceLastCrash = snapshot.activeDurationSinceLastCrash;
        g_state.backgroundDurationSinceLastCrash = snapshot.backgroundDurationSinceLastCrash;
        g_state.launchesSinceLastCrash = snapshot.launchesSinceLastCrash;
        g_state.sessionsSinceLastCrash = snapshot.sessionsSinceLastCrash;
        g_state.crashedLastLaunch = snapshot.crashedLastLaunch;
        g_state.crashedLastTimestamp = snapshot.crashedLastTimestamp;
        g_state.previousEarlyCrash = snapshot.previousEarlyCrash;
        g_state.previousEarlyCrashDurationNS = snapshot.previousEarlyCrashDurationNS;
    }
}

bool ftcrashstate_reset(void)
{
    if (g_isEnabled) {
        g_state.sessionsSinceLaunch = 1;
        g_state.activeDurationSinceLaunch = 0;
        g_state.backgroundDurationSinceLaunch = 0;
        if (g_state.crashedLastLaunch) {
            g_state.activeDurationSinceLastCrash = 0;
            g_state.backgroundDurationSinceLastCrash = 0;
            g_state.launchesSinceLastCrash = 0;
            g_state.sessionsSinceLastCrash = 0;
            g_state.crashedThisTimestamp = 0;
        }
        g_state.crashedThisLaunch = false;

        // Simulate first transition to foreground
        g_state.launchesSinceLastCrash++;
        g_state.sessionsSinceLastCrash++;
        g_state.applicationIsInForeground = true;

        bool saved = saveState(g_stateFilePath);
        if (!g_consumedHistory) {
            g_consumedHistory = true;
            if (!saved) g_state.previousEarlyCrash = false;
        }
        return saved;
    }
    return false;
}

void ftcrashstate_notifyObjCLoad(void)
{
    memset(&g_state, 0, sizeof(g_state));
    g_state.applicationIsInForeground = false;
    g_state.applicationIsActive = true;
    g_state.appStateTransitionTime = getCurrentTime();
}

void ftcrashstate_notifyAppActive(bool isActive)
{
    if (g_isEnabled) {
        g_state.applicationIsActive = isActive;
        if (isActive) {
            g_state.appStateTransitionTime = getCurrentTime();
        } else {
            double duration = timeSince(g_state.appStateTransitionTime);
            g_state.activeDurationSinceLaunch += duration;
            g_state.activeDurationSinceLastCrash += duration;
        }
    }
}

void ftcrashstate_notifyAppInForeground(bool isInForeground)
{
    if (g_isEnabled) {
        const char *const stateFilePath = g_stateFilePath;

        g_state.applicationIsInForeground = isInForeground;
        if (isInForeground) {
            double duration = getCurrentTime() - g_state.appStateTransitionTime;
            g_state.backgroundDurationSinceLaunch += duration;
            g_state.backgroundDurationSinceLastCrash += duration;
            g_state.sessionsSinceLastCrash++;
            g_state.sessionsSinceLaunch++;
        } else {
            g_state.appStateTransitionTime = getCurrentTime();
            saveState(stateFilePath);
        }
    }
}

void ftcrashstate_notifyAppTerminate(void){
    if (g_isEnabled) {
        const char *const stateFilePath = g_stateFilePath;
        updateAppState();
        saveState(stateFilePath);
    }
}

void ftcrashstate_notifyAppCrash(void)
{
    if (g_isEnabled) {
        const char *const stateFilePath = g_stateFilePath;
        updateAppState();
        g_state.crashedThisLaunch = true;
        g_state.crashedThisTimestamp = getCurrentTime();
        saveState(stateFilePath);
    }
}

const FTCrash_AppState *ftcrashstate_currentState(void) { return &g_state; }

static const char *monitorId(void) { return "ApplicationState"; }

static void setEnabled(bool isEnabled)
{
    bool expectEnabled = !isEnabled;
    if (!atomic_compare_exchange_strong(&g_isEnabled, &expectEnabled, isEnabled)) {
        // We were already in the expected state
        return;
    }

    if (isEnabled) {
        ftcrashstate_reset();
    }
}

static bool isEnabled(void) { return g_isEnabled; }

static void addContextualInfoToEvent(FTCrash_MonitorContext *eventContext)
{
    if (g_isEnabled) {
        updateAppState();
        eventContext->AppState.activeDurationSinceLastCrash = g_state.activeDurationSinceLastCrash;
        eventContext->AppState.activeDurationSinceLaunch = g_state.activeDurationSinceLaunch;
        eventContext->AppState.applicationIsActive = g_state.applicationIsActive;
        eventContext->AppState.applicationIsInForeground = g_state.applicationIsInForeground;
        eventContext->AppState.appStateTransitionTime = g_state.appStateTransitionTime;
        eventContext->AppState.backgroundDurationSinceLastCrash = g_state.backgroundDurationSinceLastCrash;
        eventContext->AppState.backgroundDurationSinceLaunch = g_state.backgroundDurationSinceLaunch;
        eventContext->AppState.crashedLastLaunch = g_state.crashedLastLaunch;
        eventContext->AppState.crashedThisLaunch = g_state.crashedThisLaunch;
        eventContext->AppState.launchesSinceLastCrash = g_state.launchesSinceLastCrash;
        eventContext->AppState.sessionsSinceLastCrash = g_state.sessionsSinceLastCrash;
        eventContext->AppState.sessionsSinceLaunch = g_state.sessionsSinceLaunch;
    }
}

FTCrashMonitorAPI *ftcrashcm_appstate_getAPI(void)
{
    static FTCrashMonitorAPI api = { 0 };
    if (ftcrashcma_initAPI(&api)) {
        api.monitorId = monitorId;
        api.setEnabled = setEnabled;
        api.isEnabled = isEnabled;
        api.addContextualInfoToEvent = addContextualInfoToEvent;
    }
    return &api;
}


bool ftcrashstate_recordEarlyCrash(uint64_t sdkStart, uint64_t captureTime)
{
    uint64_t elapsed;
    if (!g_stateFilePath || !atomic_load(&g_isEnabled) ||
        !ft_earlyCrashElapsed(sdkStart, captureTime, &elapsed)) return false;
    // First valid fact wins; every eligible handler can retry persistence even
    // when another handler is suspended or a previous write failed.
    unsigned long long expected = UINT64_MAX;
    atomic_compare_exchange_strong(&g_earlyCrashDurationNS, &expected, elapsed);
    return saveState(g_stateFilePath);
}
