//
//  FTCrashLogger.c
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/26.
//

#include "FTCrashLogger.h"
#include <os/log.h>

static volatile bool g_isEnabled = true;
static os_log_t logger = NULL;
static inline const char *lastPathEntry(const char *const path)
{
    const char *lastFile = strrchr(path, '/');
    return lastFile == 0 ? path : lastFile + 1;
}

void enableCrashMonitorLog(bool isEnabled){
    g_isEnabled = isEnabled;
    if (isEnabled) {
        if (!logger) {
            logger = os_log_create("FTSDK", "CrashMonitor");
        }
    }else{
        logger = NULL;
    }
}

void ft_asyncLogC(int levelType,const char *level, const char *file,const char *function, int line, const char *fmt, ...){
    if (g_isEnabled) {
        char buffer[256];
        va_list args;
        va_start(args, fmt);
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        switch (levelType) {
                
            case FT_LOG_LEVEL_ERROR:
                os_log_error(logger, "[FTLog][Crash][%{public}s] %{public}s %{public}s [Line %d] %{public}s",
                             level, lastPathEntry(file),function, line, buffer);
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
        
        va_end(args);
    }
}


