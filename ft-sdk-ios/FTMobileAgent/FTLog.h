//
//  FTLog.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/19.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#define FTLOG_MACRO(lvl, frmt, ...) \
[FTLog log : YES                                     \
     level : lvl                                     \
      file : __FILE__                                \
  function : __PRETTY_FUNCTION__                     \
      line : __LINE__                                \
    format : (frmt), ## __VA_ARGS__]

#define ZYDebug(...) ZYLog(__VA_ARGS__)

#define ZYLog(frmt,...)\
FTLOG_MACRO(FTLogLevelInfo,(frmt), ## __VA_ARGS__)

#define ZYErrorLog(frmt,...)\
FTLOG_MACRO(FTLogLevelError,(frmt), ## __VA_ARGS__)

#define ZYDESCLog(frmt,...)\
FTLOG_MACRO(FTLogLevelDescInfo,(frmt), ## __VA_ARGS__)
#ifndef __OPTIMIZE__
#define FTLogger(...) NSLog(__VA_ARGS__)
#else
#define FTLogger(...) {}

#endif
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, FTLogLevel){
    FTLogLevelInfo     = 1,
    FTLogLevelError,
    FTLogLevelWarning,
    FTLogLevelDescInfo
};
@interface FTLog : NSObject

+ (instancetype)sharedInstance;
+ (void)enableLog:(BOOL)enableLog;
+ (void)enableDescLog:(BOOL)enableLog;
+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... ;

@end

NS_ASSUME_NONNULL_END
