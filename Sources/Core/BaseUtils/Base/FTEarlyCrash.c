//
//  FTEarlyCrash.c
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#include "FTEarlyCrash.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>
#include <errno.h>
#include <TargetConditionals.h>

#define EARLY_WINDOW_NS UINT64_C(5000000000)
#define MARKER_MAGIC UINT64_C(0x4654454300000002)
#define EARLY_CRASH_FLAG UINT64_C(1)
#define MARKER_CHECK (~(MARKER_MAGIC ^ EARLY_CRASH_FLAG))
// Only lock-free atomics may be used while other threads are suspended.
_Static_assert(ATOMIC_BOOL_LOCK_FREE == 2, "Crash policy requires lock-free bool atomics");
_Static_assert(ATOMIC_INT_LOCK_FREE == 2 && ATOMIC_LLONG_LOCK_FREE == 2,
               "Crash policy requires lock-free descriptor and clock atomics");
struct FTEarlyCrashState {
    bool historyInitialized;
    bool recordingInitialized;
    atomic_ullong start;
    atomic_int descriptor;
    atomic_bool ready;
    atomic_bool pendingEarlyCrash;
    bool previousEarlyCrash;
    atomic_bool reserved;
};
static struct FTEarlyCrashState g_launch = { .descriptor = -1 };
static dispatch_queue_t g_preparationQueue;
static void createPreparationQueue(void *unused) {
    (void)unused;
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    g_preparationQueue = dispatch_queue_create("com.ft.early-crash", attributes);
}
dispatch_queue_t ft_earlyCrashPreparationQueue(void) {
    static dispatch_once_t once;
    dispatch_once_f(&once, NULL, createPreparationQueue);
    return g_preparationQueue;
}

typedef struct { uint64_t magic, earlyCrash, check; } EarlyMarker;
_Static_assert(sizeof(EarlyMarker) == 24, "Early crash marker format must be stable");
// All eligible events persist the same bytes. Overlapping and repeated writes
// cannot mix different timestamps/checksums, and no handler waits for another.
static const EarlyMarker kEarlyMarker = { MARKER_MAGIC, EARLY_CRASH_FLAG, MARKER_CHECK };

uint64_t ft_earlyCrashNow(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &ts) != 0) return 0;
    return (uint64_t)ts.tv_sec * UINT64_C(1000000000) + (uint64_t)ts.tv_nsec;
}
FTEarlyCrashState *ft_earlyCrashCreate(void) {
    FTEarlyCrashState *state = calloc(1, sizeof(*state));
    if (state) {
        atomic_init(&state->start, 0);
        atomic_init(&state->descriptor, -1);
        atomic_init(&state->ready, false);
        atomic_init(&state->pendingEarlyCrash, false);
        atomic_init(&state->reserved, false);
    }
    return state;
}
void ft_earlyCrashDestroy(FTEarlyCrashState *state) {
    if (!state) return;
    if (state->descriptor >= 0) close(state->descriptor);
    free(state);
}
void ft_earlyCrashRestoreHistoryInState(FTEarlyCrashState *state, const char *path) {
    // One serial I/O owner. Upload recovery does not require a capture clock or
    // an enabled Crash monitor, and never creates a current-launch file.
    if (!state || state->historyInitialized) return;
    state->historyInitialized = true;
    if (!path) goto finished;
    EarlyMarker old = {0};
    bool valid = false;
    int previous = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
    if (previous >= 0) {
        struct stat st;
        valid = fstat(previous, &st) == 0 && S_ISREG(st.st_mode) && st.st_size == sizeof(old) &&
            read(previous, &old, sizeof(old)) == sizeof(old) && old.magic == MARKER_MAGIC &&
            old.earlyCrash == EARLY_CRASH_FLAG && old.check == MARKER_CHECK;
        close(previous);
    }
    if (unlink(path) != 0 && errno != ENOENT) goto finished;
    state->previousEarlyCrash = valid;
finished:
    atomic_store_explicit(&state->ready, true, memory_order_release);
}
void ft_earlyCrashPrepareRecordingInState(FTEarlyCrashState *state, const char *path) {
    if (!state || state->recordingInitialized) return;
    state->recordingInitialized = true;
    // Recording may start before upload. Consume the old inode first, on the
    // same queue, so later upload recovery cannot delete this launch's marker.
    ft_earlyCrashRestoreHistoryInState(state, path);
    if (!path || !atomic_load(&state->start)) return;
    int descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0600);
    if (descriptor < 0) return;
    atomic_store(&state->descriptor, descriptor);
    // Paired seq_cst store/load handshakes cover events arriving before or
    // during descriptor publication, without waiting in a crash handler.
    if (atomic_load(&state->pendingEarlyCrash))
        (void)pwrite(descriptor, &kEarlyMarker, sizeof(kEarlyMarker), 0);
}
void ft_earlyCrashInitialize(FTEarlyCrashState *state, uint64_t start, const char *path) {
    // Compatibility convenience for isolated launch/process fixtures.
    ft_earlyCrashStartInState(state, start);
    ft_earlyCrashRestoreHistoryInState(state, path);
    ft_earlyCrashPrepareRecordingInState(state, path);
}
void ft_earlyCrashStartInState(FTEarlyCrashState *state, uint64_t start) {
    if (!state || !start) return;
    unsigned long long expected = 0;
    atomic_compare_exchange_strong(&state->start, &expected, start);
}
void ft_earlyCrashRecordInState(FTEarlyCrashState *state, uint64_t event) {
    if (!state) return;
    uint64_t start = atomic_load(&state->start);
    if (!start || !event || event < start) return;
    uint64_t elapsed = event - start;
    if (elapsed > EARLY_WINDOW_NS) return;
    // Every eligible handler may write independently. A suspended/interrupted
    // writer must not prevent a reentrant handler from persisting the marker.
    // One bounded async-signal-safe write, without locks, retries or fsync.
    atomic_store(&state->pendingEarlyCrash, true);
    int descriptor = atomic_load(&state->descriptor);
    if (descriptor >= 0) (void)pwrite(descriptor, &kEarlyMarker, sizeof(kEarlyMarker), 0);
}
unsigned ft_earlyCrashTakeDelayInState(FTEarlyCrashState *state) {
    if (!state || !atomic_load_explicit(&state->ready, memory_order_acquire)) return 10;
    bool consumed = atomic_exchange_explicit(&state->reserved, true, memory_order_relaxed);
    return !consumed && state->previousEarlyCrash ? 2 : 10;
}
void ft_earlyCrashBegin(uint64_t start, const char *path) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    ft_earlyCrashInitialize(&g_launch, start, path);
#else
    (void)start; (void)path;
#endif
}
void ft_earlyCrashStart(uint64_t start) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    ft_earlyCrashStartInState(&g_launch, start);
#else
    (void)start;
#endif
}
void ft_earlyCrashRecord(uint64_t event) { ft_earlyCrashRecordInState(&g_launch, event); }
unsigned ft_earlyCrashTakeUploadDelay(void) { return ft_earlyCrashTakeDelayInState(&g_launch); }

uint64_t ft_earlyCrashStartTime(void) { return atomic_load(&g_launch.start); }
void ft_earlyCrashRestoreHistory(const char *path) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    ft_earlyCrashRestoreHistoryInState(&g_launch, path);
#else
    (void)path;
#endif
}
void ft_earlyCrashPrepareRecording(const char *path) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    ft_earlyCrashPrepareRecordingInState(&g_launch, path);
#else
    (void)path;
#endif
}
