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
struct FTEarlyCrashState {
    bool initialized;
    uint64_t start;
    int descriptor;
    bool previousEarlyCrash;
    atomic_bool reserved;
};
static struct FTEarlyCrashState g_launch = { .descriptor = -1 };

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
    if (state) { state->descriptor = -1; atomic_init(&state->reserved, false); }
    return state;
}
void ft_earlyCrashDestroy(FTEarlyCrashState *state) {
    if (!state) return;
    if (state->descriptor >= 0) close(state->descriptor);
    free(state);
}
void ft_earlyCrashInitialize(FTEarlyCrashState *state, uint64_t start, const char *path) {
    // Called before installing crash handlers, on the SDK initialization thread.
    if (!state || state->initialized) return;
    state->initialized = true;
    state->start = start;
    if (!path || !start) return;
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
    // Old inode is detached before any current-launch writes can occur.
    // Never grant acceleration if consumption fails.
    if (unlink(path) != 0 && errno != ENOENT) return;
    state->descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0600);
    if (state->descriptor < 0) return;
    state->previousEarlyCrash = valid;
}
void ft_earlyCrashRecordInState(FTEarlyCrashState *state, uint64_t event) {
    if (!state || state->descriptor < 0 || !state->start || !event || event < state->start) return;
    uint64_t elapsed = event - state->start;
    if (elapsed > EARLY_WINDOW_NS) return;
    // Every eligible handler may write independently. A suspended/interrupted
    // writer must not prevent a reentrant handler from persisting the marker.
    // One bounded async-signal-safe write, without locks, retries or fsync.
    (void)pwrite(state->descriptor, &kEarlyMarker, sizeof(kEarlyMarker), 0);
}
unsigned ft_earlyCrashTakeDelayInState(FTEarlyCrashState *state) {
    if (!state || !state->initialized) return 10;
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
void ft_earlyCrashRecord(uint64_t event) { ft_earlyCrashRecordInState(&g_launch, event); }
unsigned ft_earlyCrashTakeUploadDelay(void) { return ft_earlyCrashTakeDelayInState(&g_launch); }
