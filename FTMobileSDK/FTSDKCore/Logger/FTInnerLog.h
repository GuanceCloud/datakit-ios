//
//  FTInnerLog.h
//  FTMobileSDK
//
//  Created by Codex on 2026/4/7.
//

#import "FTEnumConstant.h"
#import "FTLog.h"

#define FTLOG_MACRO(lvl, frmt, ...) \
[FTLog log : YES                                     \
     level : lvl                                     \
  function : __PRETTY_FUNCTION__                     \
      line : __LINE__                                \
    format : (frmt), ## __VA_ARGS__]

#define FTInnerLogInfo(frmt,...) FTLOG_MACRO(StatusInfo,(frmt), ## __VA_ARGS__)

#define FTInnerLogDebug(frmt,...) FTLOG_MACRO(StatusDebug,(frmt), ## __VA_ARGS__)

#define FTInnerLogError(frmt,...) FTLOG_MACRO(StatusError,(frmt), ## __VA_ARGS__)

#define FTInnerLogWarning(frmt,...) FTLOG_MACRO(StatusWarning,(frmt), ## __VA_ARGS__)

NS_ASSUME_NONNULL_BEGIN

@interface FTLog (FTInnerLog)
+ (void)log:(BOOL)asynchronous
      level:(LogStatus)level
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... NS_FORMAT_FUNCTION(5,6);
@end

NS_ASSUME_NONNULL_END
