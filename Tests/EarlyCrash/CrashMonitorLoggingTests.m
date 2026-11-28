//
//  CrashMonitorLoggingTests.m
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

#import "FTCrashLogger.h"
#import "FTInnerLog.h"
#import <os/log.h>
#include <assert.h>
#include <string.h>

static unsigned logCreations;
static unsigned logWrites;

os_log_t ft_testCreateCrashLog(const char *subsystem, const char *category)
{
    assert(strcmp(subsystem, "FTSDK") == 0);
    assert(strcmp(category, "CrashMonitor") == 0);
    ++logCreations;
    return OS_LOG_DEFAULT;
}

bool ft_testCrashLogTypeEnabled(os_log_t logger, os_log_type_t type)
{
    assert(logger == OS_LOG_DEFAULT && "Crash logger must be explicitly enabled");
    assert(type == OS_LOG_TYPE_ERROR);
    return true;
}

void ft_testWriteCrashLog(void *dso, os_log_t logger, os_log_type_t type,
                          const char *format, uint8_t *buffer, uint32_t size)
{
    (void)dso;
    (void)logger;
    (void)type;
    (void)format;
    (void)buffer;
    (void)size;
    ++logWrites;
}

int main(void)
{
    @autoreleasepool {
        FTLOG_ERROR("Default-off probe");
        assert(logCreations == 0 && logWrites == 0);
        assert(![FTLog isSwizzleLogEnabled] && ![FTLog isLoggerEnabled]);

        [FTLog enableCrashMonitorLog:YES];
        FTLOG_ERROR("Enabled probe");
        assert(logCreations == 1 && logWrites == 1);
        assert(![FTLog isSwizzleLogEnabled] && ![FTLog isLoggerEnabled]);

        [FTLog enableSwizzleLog:YES];
        [FTLog enableCrashMonitorLog:NO];
        FTLOG_ERROR("Disabled probe with Swizzle enabled");
        assert(logCreations == 1 && logWrites == 1);
        assert([FTLog isSwizzleLogEnabled] && ![FTLog isLoggerEnabled]);

        [FTLog enableCrashMonitorLog:YES];
        [FTLog enableSwizzleLog:NO];
        FTLOG_ERROR("Re-enabled probe");
        assert(logCreations == 1 && logWrites == 2);

        [FTLog enableCrashMonitorLog:NO];
        [FTLog enableLog:YES];
        FTLOG_ERROR("Disabled probe");
        assert(logCreations == 1 && logWrites == 2);
        assert(![FTLog isSwizzleLogEnabled] && [FTLog isLoggerEnabled]);
    }
    puts("Crash Monitor logging: opt-in, toggle and independence checks passed");
    return 0;
}
