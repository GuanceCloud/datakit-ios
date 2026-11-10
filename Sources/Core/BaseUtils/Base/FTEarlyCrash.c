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
#include <time.h>
#include <TargetConditionals.h>
_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2, "Crash clock requires lock-free atomics");
static atomic_ullong g_sdkStart;
uint64_t ft_earlyCrashNow(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &ts) != 0) return 0;
    return (uint64_t)ts.tv_sec * UINT64_C(1000000000) + (uint64_t)ts.tv_nsec;
}
void ft_earlyCrashStart(uint64_t start) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    if (!start) return;
    unsigned long long expected = 0;
    atomic_compare_exchange_strong(&g_sdkStart, &expected, start);
#else
    (void)start;
#endif
}
uint64_t ft_earlyCrashStartTime(void) { return atomic_load(&g_sdkStart); }
bool ft_earlyCrashElapsed(uint64_t start, uint64_t event, uint64_t *elapsed) {
    if (!start || !event || event < start || event - start > UINT64_C(5000000000)) return false;
    if (elapsed) *elapsed = event - start;
    return true;
}
