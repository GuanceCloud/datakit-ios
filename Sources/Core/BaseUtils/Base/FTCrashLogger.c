//
//  FTCrashLogger.c
//
//  Created by hulilei on 2025/6/26.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

#include "FTCrashLogger.h"
#include <dispatch/dispatch.h>
#include <os/log.h>
#include <stdatomic.h>
#include <string.h>

_Static_assert(ATOMIC_POINTER_LOCK_FREE == 2, "Crash logging requires lock-free pointer access");

static _Atomic(os_log_t) g_enabledLogger = NULL;
static os_log_t g_crashMonitorLogger;

static inline const char *lastPathEntry(const char *const path)
{
    const char *lastFile = strrchr(path, '/');
    return lastFile == 0 ? path : lastFile + 1;
}

static void createCrashMonitorLogger(void *context)
{
    (void)context;
    g_crashMonitorLogger = os_log_create("FTSDK", "CrashMonitor");
}

void enableCrashMonitorLog(bool isEnabled)
{
    os_log_t logger = NULL;
    if (isEnabled) {
        static dispatch_once_t onceToken;
        dispatch_once_f(&onceToken, NULL, createCrashMonitorLogger);
        logger = g_crashMonitorLogger;
    }
    // Keep the handle alive for crash paths that already took a snapshot.
    atomic_store_explicit(&g_enabledLogger, logger, memory_order_release);
}

void ft_asyncLogC(int levelType, const char *level, const char *file, const char *function, int line, const char *fmt, ...)
{
    os_log_t logger = atomic_load_explicit(&g_enabledLogger, memory_order_acquire);
    if (logger == NULL) {
        return;
    }

    char buffer[256];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);

    switch (levelType) {
        case FT_LOG_LEVEL_ERROR:
            os_log_error(logger, "[FTLog][Crash][%{public}s] %{public}s %{public}s [Line %d] %{public}s",
                         level, lastPathEntry(file), function, line, buffer);
            break;
        case FT_LOG_LEVEL_DEBUG:
            os_log_debug(logger, "[FTLog][Crash][%{public}s] %{public}s %{public}s [Line %d] %{public}s",
                         level, lastPathEntry(file), function, line, buffer);
            break;
        case FT_LOG_LEVEL_WARN:
        case FT_LOG_LEVEL_INFO:
        default:
            os_log_info(logger, "[FTLog][Crash][%{public}s] %{public}s %{public}s [Line %d] %{public}s",
                        level, lastPathEntry(file), function, line, buffer);
            break;
    }
}
