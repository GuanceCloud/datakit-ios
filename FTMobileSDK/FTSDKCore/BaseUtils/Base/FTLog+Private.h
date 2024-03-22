//
//  FTLog+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/7.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTLog.h"
#import "FTEnumConstant.h"
#import "FTLogMessage.h"
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

#define FT_CONSOLE_LOG(lvl, frmt,property)   \
[[FTLog sharedInstance] userLog : YES                   \
   message : frmt                                   \
     level : lvl                                    \
   property:property]

#define FTNSLogError(frmt, ...)    do{ if([FTLog isLoggerEnabled]) NSLog((frmt), ##__VA_ARGS__); } while(0)

NS_ASSUME_NONNULL_BEGIN

@class FTLogMessage;
@protocol FTDebugLogger <NSObject>
- (void)logMessage:(FTLogMessage *)logMessage NS_SWIFT_NAME(log(message:));
- (NSString *)formatLogMessage:(FTLogMessage *)logMessage;
@end


@interface FTLog ()
+ (void)enableLog:(BOOL)enableLog;
+ (void)addLogger:(id <FTDebugLogger>)logger;
+ (BOOL)isLoggerEnabled;
+ (void)log:(BOOL)asynchronous
      level:(LogStatus)level
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... NS_FORMAT_FUNCTION(5,6);
- (void)userLog:(BOOL)asynchronous
    message:(NSString *)message
      level:(LogStatus)level
   property:(nullable NSDictionary *)property;
- (void)shutDown;
@end


@interface FTAbstractLogger : NSObject <FTDebugLogger>
{
    // Direct accessors to be used only for performance
    @public
    dispatch_queue_t _loggerQueue;
}
@property (nonatomic, strong) dispatch_queue_t loggerQueue;

@end
NS_ASSUME_NONNULL_END
