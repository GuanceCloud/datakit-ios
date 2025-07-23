//
//  FTCrashLogger.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/26.
//

#ifndef FTCrashLogger_h
#define FTCrashLogger_h

#include <stdio.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define FT_LOG_LEVEL_ERROR 10
#define FT_LOG_LEVEL_WARN 20
#define FT_LOG_LEVEL_INFO 30
#define FT_LOG_LEVEL_DEBUG 40

void enableCrashMonitorLog(bool isEnabled);

void ft_asyncLogC(int levelType,const char *level, const char *file,const char *function, int line, const char *fmt, ...);

#define i_FTLOG_FULL ft_asyncLogC

#define a_FTLOG_FULL(TYPE,LEVEL, FMT, ...) i_FTLOG_FULL(TYPE,LEVEL, __FILE__,__PRETTY_FUNCTION__, __LINE__, FMT, ##__VA_ARGS__)


#define FTLOG_ERROR(FMT, ...) a_FTLOG_FULL(FT_LOG_LEVEL_ERROR,"ERROR", FMT, ##__VA_ARGS__)
#define FTLOG_DEBUG(FMT, ...) a_FTLOG_FULL(FT_LOG_LEVEL_DEBUG,"DEBUG", FMT, ##__VA_ARGS__)
#define FTLOG_INFO(FMT, ...) a_FTLOG_FULL(FT_LOG_LEVEL_INFO,"INFO", FMT, ##__VA_ARGS__)
#define FTLOG_WARN(FMT, ...) a_FTLOG_FULL(FT_LOG_LEVEL_WARN,"WARNING", FMT, ##__VA_ARGS__)

#ifdef __cplusplus
}
#endif
#endif /* FTCrashLogger_h */
